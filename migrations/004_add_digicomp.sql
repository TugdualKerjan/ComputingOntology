-- 004: integrate Digi-Comp I and Digi-Comp II.
--
-- Digi-Comp II is already half-present in the catalogue: the generic
-- `marble-adder` record calls it "the canonical plastic educational design" and
-- owns two example rows about it (digicomp-ii-demo, digicomp-ii-addition). So
-- this is a promotion, not an insert -- the examples move to the new record and
-- marble-adder stops describing a machine it isn't, which avoids creating exactly
-- the kind of near-duplicate that migration 003 cleans up.
--
-- Both are mechanical, deterministic, exact, procedural, and 100% E.S.R. Inc.
-- Their computation models differ and that is the interesting part:
--   Digi-Comp I  -- three mechanical flip-flops, peg-programmed, lever clock.
--                   Wikipedia calls it a finite-state machine, and it is one.
--   Digi-Comp II -- gravity-fed marbles over cams; NOT programmable, so it is a
--                   fixed circuit, not a state machine with a program. Scott
--                   Aaronson's analysis puts it in the complexity class CC
--                   (comparator circuits), which is why it is filed under logic
--                   gates rather than finite-state machines.
--
-- Sources: https://en.wikipedia.org/wiki/Digi-Comp_I
--          https://en.wikipedia.org/wiki/Digi-Comp_II

.bail on
BEGIN;

INSERT OR REPLACE INTO systems
  (id, name, realizes, description, determinism, reversibility, exactness, realization_type, computation_model)
VALUES
  ('digicomp-i',
   'Digi-Comp I',
   'boolean logic / 3-bit sequential programs (addition, subtraction, Nim)',
   'A polystyrene kit computer sold by E.S.R., Inc. from 1963 for $4.99. Three mechanical flip-flops hold the machine state, read out as three binary digits. The program is the physical arrangement of cylindrical pegs on the flip-flop slides: thin vertical wires are either pushed or blocked from moving by the pegs, so each peg is one term of a boolean transition rule. A lever worked back and forth supplies the clock, gating the wires and advancing the state one step per stroke. Programs shipped with the kit include binary addition and subtraction and the game of Nim. Marketed as "an actual working digital computer", it is more precisely a hand-clocked finite-state machine — which makes it one of the few entries here whose computational model is unambiguous. Speed: one state transition per lever stroke (operator-limited, roughly 1 Hz). Capacity: 3 bits of state; peg-programmed transition table.',
   'deterministic', 'irreversible', 'exact', 'procedural', '["Finite-state machines"]'),
  ('digicomp-ii',
   'Digi-Comp II',
   'binary arithmetic via gravity-driven marble cascade (add, multiply, count)',
   'A marble-driven binary calculator invented by John Thomas Godfrey in 1965 and sold by E.S.R., Inc. in the late 1960s. Half-inch marbles roll down a two-level masonite platform, 14 by 28.5 inches (36 cm × 72 cm), guided by blue plastic channels. Gravity is the clock: releasing a marble advances the computation by one step, with no external power. Red plastic cams act as the bits — a marble passing a cam flips it, and the cam''s orientation decides whether the next marble passes through or drops to the level below, giving a mechanical flip-flop with fan-out. Chaining cams yields binary addition, multiplication, division and counting. Unlike the Digi-Comp I it is not programmable: the wiring is the machine, so it is a fixed circuit rather than a stored-program device. Scott Aaronson analysed it as solving problems in the complexity class CC (comparator circuits), making it a physical instance of a class that is neither obviously parallelizable nor P-complete. Speed: seconds per operation (marble transit time). Capacity: a few bits per register; fixed layout.',
   'deterministic', 'irreversible', 'exact', 'procedural', '["Logic gates and digital circuits"]');

INSERT OR IGNORE INTO system_substrates (system_id, substrate_id) VALUES
  ('digicomp-i',  'mechanical'),
  ('digicomp-ii', 'mechanical');

-- Move the Digi-Comp II examples off the generic marble-adder record.
UPDATE examples SET system_id = 'digicomp-ii'
WHERE id IN ('digicomp-ii-demo', 'digicomp-ii-addition');

INSERT OR REPLACE INTO examples
  (id, system_id, label, url, description, operations, speed_category, scale_category, energy_per_operation)
VALUES
  ('digicomp-i-wikipedia', 'digicomp-i',
   'Wikipedia — Digi-Comp I',
   'https://en.wikipedia.org/wiki/Digi-Comp_I',
   'History and mechanism of the 1963 E.S.R. polystyrene kit: three flip-flops, peg-programmed wire logic, and a hand lever for a clock.',
   '["AND", "OR", "NOT", "ADD", "SUBTRACT", "STORE"]',
   'seconds', 'small', 'J'),
  ('digicomp-ii-wikipedia', 'digicomp-ii',
   'Wikipedia — Digi-Comp II',
   'https://en.wikipedia.org/wiki/Digi-Comp_II',
   'Construction and operation of the marble binary calculator, plus Aaronson''s placement of it in the complexity class CC.',
   '["ADD", "MULTIPLY", "DIVIDE", "COUNT", "SHIFT"]',
   'seconds', 'small', 'J');

-- marble-adder stays as the generic gravity-marble-logic record, but hands the
-- Digi-Comp II specifics over to the record that now owns them.
UPDATE systems
SET description = replace(description,
      'The Digi-Comp II (1965) is the canonical plastic educational design, while K''NEX construction sets allow modular prototyping of custom layouts.',
      'K''NEX and wooden construction sets allow modular prototyping of custom layouts; the mass-produced plastic instance of this design is catalogued separately as the Digi-Comp II.')
WHERE id = 'marble-adder';

SELECT 'after' AS stage, id, name, computation_model FROM systems
WHERE id IN ('digicomp-i', 'digicomp-ii', 'marble-adder');
SELECT 'examples' AS stage, system_id, COUNT(*) AS n FROM examples
WHERE system_id IN ('digicomp-i', 'digicomp-ii', 'marble-adder') GROUP BY system_id;
SELECT 'system count' AS check_, COUNT(*) AS n FROM systems;
SELECT 'orphan examples' AS check_, COUNT(*) AS n FROM examples e
  WHERE NOT EXISTS (SELECT 1 FROM systems s WHERE s.id = e.system_id);

COMMIT;
