-- 001: the biological brain is not a finite-state computation model.
--
-- Before: computation_model = '["Finite-state machines"]'
-- After:  computation_model = '["???"]'
--
-- An FSM has a finite, globally-enumerable state set and one locus of control.
-- The brain has neither: ~10^15 synapses under continuous STDP means state is not
-- a fixed finite set, and computation is asynchronous and local with no global
-- controller. The honest answer is that no model in this catalogue's vocabulary
-- (register machines, logic gates, synchronous data flow, cellular automaton,
-- finite-state machines, Turing machines) describes it -- so it gets its own
-- category that says exactly that, rather than being filed under the nearest
-- wrong box.
--
-- '???' is a real vocabulary entry, not a null: it is meant to be clickable and
-- to accumulate members as other entries turn out not to fit either.
--
-- Format note: database.py matches this column with LIKE '%"value"%' and parses
-- it as JSON, so keep the exact '["..."]' shape (json.dumps spacing).

.bail on
BEGIN;

SELECT 'before' AS stage, id, computation_model
FROM systems WHERE id IN ('biological-brain', 'dishbrain');

UPDATE systems
SET computation_model = '["???"]'
WHERE id = 'biological-brain'
  AND computation_model = '["Finite-state machines"]';

-- OPTIONAL, same argument: DishBrain is ~800k live cortical neurons
-- self-organizing under the free-energy principle -- the same substrate as the
-- row above, just smaller, so it inherits the same objection. Delete this
-- statement to keep '???' a category of exactly one.
UPDATE systems
SET computation_model = '["???"]'
WHERE id = 'dishbrain'
  AND computation_model = '["Finite-state machines"]';

SELECT 'after' AS stage, id, computation_model
FROM systems WHERE id IN ('biological-brain', 'dishbrain');

SELECT 'vocab' AS stage, computation_model, COUNT(*) AS n
FROM systems GROUP BY computation_model ORDER BY n DESC;

COMMIT;
