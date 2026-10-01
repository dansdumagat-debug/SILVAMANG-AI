"""One fixed 50/50 weight-space blend; validation selection only, no deployment."""
import json
from pathlib import Path
import numpy as np
import pandas as pd
import torch
from evaluate_identification_candidates import summarize
from train_corrected_classifier import write_json, checkpoint


def main():
    root = Path(__file__).resolve().parents[1]
    run = root/'artifacts/classifier_corrected/20260928T124128799011Z'
    experiment = root/'artifacts/identification_improvement/regularized_head_v1'
    output = root/'artifacts/identification_improvement/blended_head_v1'
    output.mkdir(parents=True,exist_ok=False)
    torch.set_num_threads(2)
    saved = torch.load(run/'efficientnet_b0_best.pth',map_location='cpu',weights_only=True)
    classes = saved['classes']
    data = np.load(experiment/'val_features.npz')
    features, truth = torch.from_numpy(data['features']),data['labels']
    head = np.load(experiment/'head_C_0.01_head.npz')
    state = saved['model_state_dict']
    old_weight,old_bias = state['classifier.1.weight'],state['classifier.1.bias']
    weight = (old_weight+torch.tensor(head['weight'],dtype=torch.float32))/2
    bias = (old_bias+torch.tensor(head['bias'],dtype=torch.float32))/2
    with torch.inference_mode():
        base = torch.nn.functional.linear(features,old_weight,old_bias).softmax(1).numpy()
        probabilities = torch.nn.functional.linear(features,weight,bias).softmax(1).numpy()
    baseline,_ = summarize(base,truth,classes)
    metrics,report = summarize(probabilities,truth,classes)
    assert abs(baseline['macro_f1']-saved['validation']['macro_f1'])<1e-6
    improved = (metrics['accuracy']>baseline['accuracy'] and metrics['macro_f1']>baseline['macro_f1']
                and metrics['unknown_false_accepts']<=baseline['unknown_false_accepts'])
    write_json(output/'comparison.json',dict(baseline=baseline,candidate=metrics,improved=improved,
               recipe='Equal weight-space blend of original head and train-only balanced C=0.01 head',
               deployed=False,test_evaluated=False,limitation='Validation-selected; independent final evaluation required.'))
    write_json(output/'per_class_validation.json',report)
    rows = pd.read_csv(run/'split_manifest.csv')
    rows = rows[rows.split=='val'].copy()
    assert np.array_equal(rows.label.to_numpy(),truth)
    rows['prediction']=[classes[i] for i in probabilities.argmax(1)]
    rows['confidence']=probabilities.max(1)
    rows.to_csv(output/'validation_predictions.csv',index=False)
    if improved:
        state['classifier.1.weight'],state['classifier.1.bias']=weight,bias
        saved['validation']=metrics
        saved['head_refit']=dict(recipe='original_and_balanced_C_0.01_equal_weight_blend',validation_selected=True)
        checkpoint(output/'candidate.pth',saved)
        write_json(output/'class_order.json',classes)
    print((output/'comparison.json').read_text(),flush=True)


if __name__=='__main__':main()
