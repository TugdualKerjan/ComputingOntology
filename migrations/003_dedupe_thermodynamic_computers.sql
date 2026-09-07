-- 003: collapse the duplicated Normal Computing SPU records.
--
-- Four rows currently crowd the same search results:
--
--   analog-annealing            Simulated annealing (thermal)          -> KEEP
--   thermodynamic-computer      Thermodynamic computer                 -> KEEP (generic class)
--   thermodynamic-computer-spu  Thermodynamic computer (Normal ... SPU) -> KEEP (concrete device)
--   normal-computing-spu        Normal Computing stochastic proc. units -> DELETE (duplicate device)
--
-- The last two are the same hardware described twice. thermodynamic-computer-spu
-- is the better record (RLC unit cells, all-to-all switched-capacitance coupling,
-- Langevin/OU dynamics) and its metadata is right; normal-computing-spu is tagged
-- deterministic/exact/Synchronous-Data-Flow, which is wrong for a device whose
-- whole premise is sampling from physical noise. So the SPU keeps one row, and
-- the CN101 prototype example moves onto it rather than being lost.
--
-- Generic-plus-instance is kept deliberately: it is the pattern already used for
-- neuromorphic-chip (generic) alongside intel-loihi-1/2 and ibm-truenorth.
-- analog-annealing stays because annealing is a method (argmin of a cost
-- landscape), not this device -- though note it and thermodynamic-computer carry
-- identical property tuples and identical substrates, which is why they read as
-- near-duplicates in the list. Worth a separate look.

.bail on
BEGIN;

SELECT 'before' AS stage, id, name, determinism, exactness, computation_model
FROM systems WHERE id LIKE '%thermodynamic%' OR id = 'normal-computing-spu' OR id = 'analog-annealing';

-- 1. Move the example onto the surviving record (id kept for traceability).
UPDATE examples
SET system_id = 'thermodynamic-computer-spu'
WHERE system_id = 'normal-computing-spu';

-- 2. The surviving record has substrates electronic + thermodynamic already, so
--    the duplicate's thermodynamic-only link adds nothing. Drop it.
DELETE FROM system_substrates WHERE system_id = 'normal-computing-spu';

-- 3. Fold the one fact the duplicate carried that the survivor did not: the
--    memristive elements and the ASIC framing.
UPDATE systems
SET realizes = 'probabilistic sampling / linear algebra via thermal equilibration',
    description = description || ' The SPU line is realized as analog probabilistic ASICs with memristive elements and thermodynamic noise shaping, targeting AI inference rather than general-purpose compute.'
WHERE id = 'thermodynamic-computer-spu'
  AND description NOT LIKE '%memristive elements%';

-- 4. Remove the duplicate.
DELETE FROM systems WHERE id = 'normal-computing-spu';

SELECT 'after' AS stage, id, name, determinism, exactness, computation_model
FROM systems WHERE id LIKE '%thermodynamic%' OR id = 'analog-annealing';

SELECT 'orphan examples' AS check_, COUNT(*) AS n FROM examples e
  WHERE NOT EXISTS (SELECT 1 FROM systems s WHERE s.id = e.system_id);
SELECT 'orphan links' AS check_, COUNT(*) AS n FROM system_substrates ss
  WHERE NOT EXISTS (SELECT 1 FROM systems s WHERE s.id = ss.system_id);
SELECT 'system count' AS check_, COUNT(*) AS n FROM systems;

COMMIT;
