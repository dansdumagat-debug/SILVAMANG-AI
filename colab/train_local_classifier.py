"""Run or resume the same candidate training workflow on local data."""
import argparse
import os
from pathlib import Path
import runpy

if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=root / 'dataset/retraining/EfficientNet-B0/rebuild_20260926')
    parser.add_argument('--output', type=Path, default=root / 'artifacts/classifier_retraining')
    parser.add_argument('--resume', type=Path)
    parser.add_argument('--checkpoint', type=Path)
    parser.add_argument('--balanced', action='store_true')
    args = parser.parse_args()
    os.environ['SILVAMANG_TRAIN_SOURCE'] = str(args.source.resolve())
    os.environ['SILVAMANG_TRAIN_OUTPUT'] = str(args.output.resolve())
    os.environ['SILVAMANG_BALANCED'] = '1' if args.balanced else '0'
    if args.checkpoint:
        os.environ['SILVAMANG_INITIAL_CHECKPOINT'] = str(args.checkpoint.resolve())
    if args.resume:
        os.environ['SILVAMANG_RESUME_RUN'] = str(args.resume.resolve())
    runpy.run_path(str(root / 'colab/retrain_current_classifier.py'), run_name='__main__')
