-- 005: one substrate per system.
--
-- Two parts.
--
-- PART A -- systems that have silicon-die or discrete-logic-board lose
-- 'electronic'. Migration 002 added the finer substrate alongside the coarse one
-- deliberately, to avoid changing two things at once; this is the other half.
-- 145 systems are affected (138 silicon, 7 discrete). Note what 'Electronic'
-- means afterwards: electronic computers that are NOT a catalogued die or board
-- -- memristor crossbars, op-amp analog computers, teledeltos sheets.
--
-- PART B -- the 15 systems that carry two (or three) substrates for reasons
-- unrelated to 002 each get the one that actually does the computing. The rule
-- used: pick the medium the computation happens IN, not the medium that reads it
-- out or drives it. So a MEMS accelerometer is mechanical (a proof mass on
-- springs, sensed capacitively), a coherent Ising machine is optical (DOPO pulses
-- in a fibre cavity, with electronics only closing the feedback loop), and a
-- boson sampler is optical (photons in an interferometer -- its quantumness is
-- already recorded in determinism and computation_model).
--
-- TWO CALLS I AM NOT CONFIDENT ABOUT, both because the entry is deliberately
-- substrate-agnostic and the rule has nothing to bite on:
--   reservoir-computer   -- "Speed: depends on reservoir substrate"; the reservoir
--                           can be a photonic loop, a bucket of water, or an RC
--                           network. Given 'electronic' here because the named
--                           implementations (echo state networks, liquid state
--                           machines) are electronic. Was electronic+mechanical+optical.
--   kuramoto-oscillators -- "pendula, LC circuits, or CMOS ring oscillators".
--                           Given 'electronic' because the MAX-CUT realizations
--                           are CMOS/LC. Was electronic+mechanical.
-- If the one-substrate rule should have an escape hatch, these two are the
-- argument for it.
--
-- PART D -- three neuromorphic chips were left on 'electronic' by migration 002
-- purely because no bespoke *-die/-package substrate row happened to exist for
-- them, which left Loihi 1 on Silicon die and Loihi 2 on Electronic, and
-- SpiNNaker on Silicon die while TrueNorth -- whose own realization_type reads
-- "45 nm CMOS neurosynaptic chip" -- sat on Electronic. All three are CMOS parts;
-- fixed here so the family is consistent.
--
-- Left on 'electronic' on purpose: neuromorphic-chip is the generic class row
-- (the pattern used for thermodynamic-computer too), and the memristor crossbar
-- entries compute in the resistive element rather than in CMOS logic.
--
-- PART C -- a unique index makes the invariant real, so a future insert cannot
-- quietly reintroduce a second substrate. Mirrored in database.py init_database.

.bail on
BEGIN;

SELECT 'before: systems with >1 substrate' AS check_, COUNT(*) AS n FROM (
  SELECT system_id FROM system_substrates GROUP BY system_id HAVING COUNT(*) > 1);

-- PART A
DELETE FROM system_substrates
WHERE substrate_id = 'electronic'
  AND system_id IN (
    SELECT system_id FROM system_substrates
    WHERE substrate_id IN ('silicon-die', 'discrete-logic-board'));

-- PART B
CREATE TEMP TABLE chosen_substrate (system_id TEXT PRIMARY KEY, substrate_id TEXT NOT NULL);
INSERT INTO chosen_substrate (system_id, substrate_id) VALUES
  ('analog-annealing',           'thermodynamic'),  -- the heat bath is the computer
  ('boson-sampler',              'optical'),        -- photons in a linear optical network
  ('coherent-ising-machine',     'optical'),        -- DOPO pulses in a fibre ring cavity
  ('dna-strand-displacement',    'chemical'),       -- strand displacement in solution, no cell
  ('fire-control-computer',      'mechanical'),     -- cams, gears and integrators
  ('gate-quantum-computer',      'quantum'),
  ('kuramoto-oscillators',       'electronic'),     -- see note above
  ('mems-accelerometer',         'mechanical'),     -- proof mass on springs, sensed capacitively
  ('photonic-chip',              'optical'),
  ('quantum-annealer',           'quantum'),
  ('quantum-gate-computer',      'quantum'),
  ('repressilator',              'biological'),     -- a gene circuit in a living cell
  ('reservoir-computer',         'electronic'),     -- see note above
  ('thermodynamic-computer',     'thermodynamic'),
  ('thermodynamic-computer-spu', 'thermodynamic');

-- Guard: every listed system must already hold the substrate being kept, or the
-- delete below would strip it of all substrates.
SELECT 'missing chosen link (must be 0)' AS check_, COUNT(*) AS n
FROM chosen_substrate c
WHERE NOT EXISTS (SELECT 1 FROM system_substrates ss
                  WHERE ss.system_id = c.system_id AND ss.substrate_id = c.substrate_id);

DELETE FROM system_substrates
WHERE EXISTS (SELECT 1 FROM chosen_substrate c
              WHERE c.system_id = system_substrates.system_id
                AND c.substrate_id <> system_substrates.substrate_id);

-- PART D (before the index, so the swap is not blocked mid-flight)
DELETE FROM system_substrates
WHERE system_id IN ('intel-loihi-2', 'ibm-truenorth', 'brainscales');

INSERT INTO system_substrates (system_id, substrate_id) VALUES
  ('intel-loihi-2', 'silicon-die'),   -- 4nm FinFET asynchronous neuromorphic cores
  ('ibm-truenorth', 'silicon-die'),   -- 45 nm CMOS neurosynaptic chip
  ('brainscales',   'silicon-die');   -- analog wafer-scale CMOS

-- PART C
CREATE UNIQUE INDEX IF NOT EXISTS idx_system_substrates_single
  ON system_substrates(system_id);

-- Post-checks
SELECT 'systems with >1 substrate' AS check_, COUNT(*) AS n FROM (
  SELECT system_id FROM system_substrates GROUP BY system_id HAVING COUNT(*) > 1);
SELECT 'systems with 0 substrates' AS check_, COUNT(*) AS n FROM systems s
  WHERE NOT EXISTS (SELECT 1 FROM system_substrates ss WHERE ss.system_id = s.id);
SELECT s.name, COUNT(ss.system_id) AS systems FROM substrates s
  LEFT JOIN system_substrates ss ON s.id = ss.substrate_id
  GROUP BY s.id HAVING systems > 0 ORDER BY systems DESC;

COMMIT;
