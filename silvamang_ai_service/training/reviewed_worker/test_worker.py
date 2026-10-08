import importlib.util
import unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('worker',Path(__file__).with_name('worker.py'))
w=importlib.util.module_from_spec(spec);spec.loader.exec_module(w)
class EligibilityTest(unittest.TestCase):
 def test_duplicates_conflicts_and_baseline_are_excluded(self):
  def row(sha,species='A',part='leaves'):return dict(sha256=sha,species=species,plant_part=part)
  rows=[row('old'),row('new'),row('new'),row('conflict'),row('conflict','B'),row('unknown','C'),row('canopy',part='full_tree')]
  self.assertEqual([r['sha256'] for r in w.eligible_rows(rows,['A','B'],{'old'})],['new'])
 def test_accuracy_alone_cannot_pass_gate(self):
  base=dict(accuracy=.8,macro_f1=.7,recall=[.9,.6])
  self.assertFalse(w.gate(dict(accuracy=.85,macro_f1=.69,recall=[.9,.6]),base))
  self.assertFalse(w.gate(dict(accuracy=.85,macro_f1=.8,recall=[.9,.4]),base))
  self.assertFalse(w.gate(base,base))
  self.assertTrue(w.gate(dict(accuracy=.81,macro_f1=.71,recall=[.9,.61]),base))
if __name__=='__main__':unittest.main()
