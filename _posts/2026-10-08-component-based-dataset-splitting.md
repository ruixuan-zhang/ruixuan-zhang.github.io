---
layout: post
title: "Component-Based Dataset Splitting: Counts, Length Bias, and Trade-offs"
description: "A reproducible synthetic experiment showing how component-based splits can match sample counts while shifting length distributions and changing evaluation scores."
date: 2026-10-08
lang: en
tags: [machine-learning, dataset-splitting, reproducibility]
categories: [research]
thumbnail: assets/img/blog/component-based-dataset-splitting/01_split_quality.png
featured: true
related_posts: false
---

To evaluate whether machine-learning models for proteins can generalize to unseen sequences, datasets are usually divided into training, validation, and test sets. These splits often enforce a maximum similarity threshold between subsets rather than assigning proteins entirely at random. This creates a more stringent test of generalization to remote homologs.

However, similarity-aware splitting can introduce bias because related proteins may share properties such as sequence length. This relationship can create systematic differences among the resulting subsets. If this shift is ignored, a model may learn shortcuts associated with the split rather than the biological signal of interest.

Here, I compare several splitting strategies and examine the caveats of component-based splitting.

A component is a group of samples that must remain in the same subset. In protein sequence analysis, components may represent clusters defined by sequence similarity, structural similarity, or another measure. If one member of a component is assigned to training, every member of that component is assigned there. This rule prevents closely related samples from being distributed across the training, validation, and test sets, although component sizes can vary substantially.

> **About the data:** Every numerical result in this post comes from an independently designed synthetic experiment. No confidential data, statistics, or experimental results were used to fit the generator. Samples are numerical feature vectors; “length” is a simulated attribute in arbitrary units. This is an experiment about split allocation, not a benchmark on real protein sequences.

> **Experiment archive:** The complete 82 MB package, including data, code, predictions, and saved models, is archived locally and is available on request.

## A small, controlled dataset

To examine these effects, I generated synthetic datasets, each containing **7,680 samples, 192 components, and eight classes**. Each class contains 960 samples distributed across 24 components. Every component contains samples from only one class, which avoids the additional constraints introduced by components spanning multiple labels.

The four scenarios vary component sizes and their relationship with length:

| Scenario               | Component sizes                            | Size–length relationship     |
| ---------------------- | ------------------------------------------ | ---------------------------- |
| `balanced_independent` | Moderately balanced: 24–56 samples each    | Independent in the generator |
| `balanced_associated`  | Moderately balanced: 24–56 samples each    | Positively associated        |
| `heavy_independent`    | A few large components and many small ones | Independent in the generator |
| `heavy_associated`     | A few large components and many small ones | Positively associated        |

In each heavy-tailed scenario, every class has two large components containing **420 and 200 samples**. The other 22 components contain 340 samples in total. Sample counts and class totals are identical across scenarios.

Lengths are generated at the component level, with additional variation between samples. In the associated scenarios, standardized log component size contributes to log length, with a fixed association parameter of 0.9. That is a generator parameter, not a promise that the observed data have a correlation of exactly 0.9. Likewise, an independent generating mechanism does not guarantee zero empirical correlation in a finite dataset.

Each sample has 18 numerical features:

- **Six signal features**, generated from a class center, a component-level perturbation, and sample-level noise.
- **Twelve component-shared nuisance features**, generated independently of the class centers but similar among samples from the same component.

The signal-noise standard deviation is set to `0.65 × sqrt(300 / length)`. Longer samples therefore have cleaner class signals **by construction**. This is a controlled assumption for studying evaluation difficulty, not a biological result. Length, sample IDs, component IDs, and split membership are never supplied as model inputs.

For each data-generation seed, a separate **probe set** contains 2,304 samples from 96 new components, covering all classes and short, medium, and long length ranges. All scenarios and methods use the same probe for that seed. Probe generation uses separate random streams; its components never enter training or split optimization. Its length distribution is chosen separately and need not match any method’s test distribution.

## Four splitting strategies, two fixed models

I evaluated four strategies for constructing the training, validation, and test sets.

The target sample proportions are **70% training, 15% validation, and 15% test**.

| Method              | Allocation rule                                                  | Keeps components intact?  |
| ------------------- | ---------------------------------------------------------------- | ------------------------- |
| `random_rows`       | Randomly split samples, stratified by class                      | No; a reference condition |
| `random_components` | Randomly split components, stratified by class                   | Yes                       |
| `count_balanced`    | Minimize deviations from class-specific sample targets           | Yes                       |
| `length_balanced`   | Balance class-specific counts and within-class length histograms | Yes                       |

The last two methods use a size-ordered greedy initialization followed by up to 12 rounds of legal component moves and same-class swaps. Every subset must retain every class. These are heuristics, with no claim of global optimality.

The length-aware objective adds normalized squared deviations for four within-class length bins, using boundaries of 160, 320, and 640 and a fixed weight of 0.30. **Counts and length balance are soft objectives; component integrity is a hard constraint.** There is no hard cap on sample-count error.

Two models are specified before examining the results:

- **Signal LR:** `StandardScaler` followed by logistic regression with `C=1`, using the six signal features.
- **All-feature 5-NN:** `StandardScaler` followed by five-nearest-neighbor classification, using all 18 features.

Scalers are fitted on training samples only. Validation scores are reported as diagnostics; there is no tuning, early stopping, or model selection. Neither test nor probe scores are used to choose a split. The two models differ in both algorithm and input features, so their comparison is not a single-factor ablation.

There are five generation seeds—101, 202, 303, 404, and 505—and six assignment seeds—11, 22, 33, 44, 55, and 66. Across all scenarios and methods, this produces **480 assignments and 960 model fits**. Every planned run is retained.

All “mean ± SD” values below summarize the 30 generation/assignment combinations for a scenario and method. These are **nested repetitions, not 30 independently generated datasets**. The standard deviations describe variability; they are not confidence intervals. The downloadable results also include assignment-seed averages within each generation seed.

## Exact sample counts can hide a large length shift

Start with `heavy_associated`: large components tend to contain longer samples.

The table reports the largest absolute deviation from a target sample fraction, in percentage points, and the first Wasserstein distance between training and test lengths. A smaller distance means more similar length distributions. Within-class distances are calculated separately for each class and then averaged equally across classes.

| Method              | Max. sample-fraction error (pp) | Overall length distance | Mean within-class length distance |
| ------------------- | ------------------------------: | ----------------------: | --------------------------------: |
| `random_rows`       |                     0.00 ± 0.00 |             17.8 ± 10.7 |                        44.6 ± 9.2 |
| `random_components` |                     8.55 ± 3.87 |           294.0 ± 185.1 |                     614.3 ± 119.5 |
| `count_balanced`    |                     0.00 ± 0.00 |            890.5 ± 80.7 |                      890.6 ± 80.6 |
| `length_balanced`   |                     4.52 ± 1.60 |           335.7 ± 137.9 |                     566.7 ± 108.4 |

For example, a test fraction of 10% against a target of 15% contributes an error of five percentage points.

The count-balanced method meets its sample targets exactly, yet produces the largest length shift. Across runs, mean training length is **1,126.5**, compared with **236.0** in the test set. Its training set contains **48 of the 192 components**, while validation and test each contain 72.

That is 70% of the samples but only 25% of the components in training. Component count is a useful separate diagnostic, although it is not itself a guarantee of statistical independence or an estimate of effective sample size.

### Why the large components end up in training

The structure of this example explains the result. Each class has 960 samples, so its exact targets are:

```text
Training: 672     Validation: 144     Test: 144
```

The two largest components contain 420 and 200 samples. Each exceeds the capacity of either held-out subset. **If the class-specific sample targets must be met exactly, both components must go into training.** Together they account for 620 of its 672 samples.

When large components also contain longer samples, this count constraint selects for length. The argument depends on exact class-specific targets; it does not carry over unchanged when those constraints are relaxed.

The length-aware objective reduces the overall distance from about **890.5 to 335.7**, at the cost of a mean maximum sample-fraction error of **4.52 percentage points**. It does not dominate the random-component method on every metric: random components achieve a smaller overall length distance, but worse within-class distances and count errors.

![Sample-fraction errors and log-length distances across all four synthetic scenarios.](/assets/img/blog/component-based-dataset-splitting/01_split_quality.png)

_Figure 1. Bars and error bars show means and standard deviations over 30 nested combinations. The lower panels use Wasserstein distances on log length; the table uses raw synthetic length units. The random-row reference permits components to cross subset boundaries._

![Sample-weighted training and test length distributions for each splitting strategy.](/assets/img/blog/component-based-dataset-splitting/02_length_ecdf.png)

_Figure 2. Empirical cumulative distributions for the prespecified example with generation seed 101 and assignment seed 11 in the heavy/associated scenario. Each sample has equal weight; components are not weighted equally. Aggregate conclusions use all runs._

The other scenarios help put this result in context. For count balancing, the overall length distance rises from **37.9 to 141.7** when size–length association is introduced in the moderately balanced case, and from **48.2 to 890.5** in the heavy-tailed case.

These comparisons support a conditional explanation: **component sizes, their relationship with length, and the allocation rule interact**. They do not establish that component-based splitting always favors long training samples.

## What changes after training a model?

The next table reports accuracy, in percent, for each method’s own test set and the shared probe. It uses the same heavy/associated scenario. Validation scores, macro-F1, and length-stratified accuracies are available in the download.

| Method              | Signal LR: test | Signal LR: probe |    5-NN: test |  5-NN: probe |
| ------------------- | --------------: | ---------------: | ------------: | -----------: |
| `random_rows`       |    90.00 ± 1.21 |     76.96 ± 0.88 |  99.49 ± 0.22 | 51.64 ± 2.68 |
| `random_components` |    84.78 ± 6.57 |     76.76 ± 0.96 | 49.04 ± 15.71 | 49.45 ± 2.97 |
| `count_balanced`    |    77.15 ± 1.64 |     75.95 ± 1.17 |  45.18 ± 4.67 | 43.84 ± 2.58 |
| `length_balanced`   |    85.92 ± 3.34 |     76.68 ± 1.00 | 49.27 ± 11.00 | 48.77 ± 3.09 |

Under random sample splitting, an average of **190.2 of the 192 components** appear in more than one subset. The 5-NN model scores nearly 99.5% on that test set but about 51.6% on the new-component probe.

The first evaluation allows samples from familiar components. It therefore does not answer the same question as evaluation on new components. However, test and probe also differ in their length distributions, so the entire gap cannot be attributed quantitatively to component overlap.

The logistic-regression results reveal a second trap. Switching from count balancing to length balancing raises test accuracy from 77.15% to 85.92%—a difference of **8.77 percentage points**. On the shared probe, the corresponding scores are 75.95% and 76.68%, a difference of only **about 0.7 percentage points**.

Calling the first change an 8.77-point improvement in generalization would be misleading. The splitting strategy changed both the training set and the population being tested.

The shared probe fixes the evaluation population within each generation seed, but training sample counts, component coverage, and feature distributions can still change together. It measures the combined effect of an allocation strategy under a fixed training procedure, not the isolated causal effect of length balance.

There is no universal winner here. For example, random-row training gives 5-NN its highest mean probe accuracy among the four strategies. The reason to require component isolation is the intended evaluation question, not a promise that an isolated split will maximize model performance.

![Actual validation, test, and shared-probe accuracy for both fixed models.](/assets/img/blog/component-based-dataset-splitting/03_model_scores.png)

_Figure 3. Actual model fits in the heavy/associated scenario. Test membership differs between methods; the probe is identical within a generation seed. Error bars show standard deviations over nested runs._

![Shared-probe results paired by generation seed and stratified by synthetic length.](/assets/img/blog/component-based-dataset-splitting/04_probe_detail.png)

_Figure 4. Top: results averaged over the six assignment seeds within each generation seed. Bottom: probe accuracy for observed lengths below 160, from 160 to below 400, and at least 400. These reporting thresholds differ from the allocation objective’s four bins. Lower noise for longer samples is a generator assumption._

## Some allocation targets are impossible

A splitting heuristic can fail because it found a poor solution, or because no solution satisfies the requested constraints. Those are different situations.

Consider 20 samples in three indivisible components:

```text
Component sizes:         [16, 2, 2]
Target counts, 70/15/15: [14, 3, 3]
```

Every target is an integer, so rounding is not the problem. The largest component exceeds every subset’s target capacity. If all three subsets must be nonempty, the best allocation is 80/10/10, with a maximum error of at least ten percentage points. The accompanying `examples.py` checks every nonempty assignment and verifies this bound.

Class coverage has its own limit: if a class appears in only two components, it cannot appear in three disjoint subsets while those components remain intact, no matter how many samples they contain.

Before optimizing a split, inspect component sizes and the number of components supporting each class. Then decide which requirements are hard constraints and which are preferences. Failure of a particular heuristic is not proof of infeasibility. Existing grouped stratification methods also seek to preserve class proportions subject to group isolation; they cannot guarantee perfect stratification for arbitrary groups. [StratifiedGroupKFold documentation](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.StratifiedGroupKFold.html).

## Reproduce the experiment

The complete experiment package includes the generator, splitting and training scripts, data, all predictions, summary tables, figure source data, and 32 saved model pipelines. The archive is available on request. The saved pipelines cover every scenario and method for generation seed 101 and assignment seed 11; the remaining fits can be reproduced from the recorded parameters.

With Python 3.12, run these commands from the extracted project directory:

```bash
python -m pip install -r requirements.txt
python run_experiment.py --quick
python run_experiment.py
python examples.py
python verify_artifacts.py
python render_results.py
python publish_english.py
```

The quick run writes to a separate `smoke/` directory. The full run writes to `artifacts/`. No GPU is required. The recorded full run took approximately **97.5 seconds** for data generation, splitting, model fitting, and result writing, excluding independent verification and plotting. Runtime will vary with hardware and software; recorded versions are in `artifacts/config.json`.

To inspect a dataset and its assigned subsets:

```python
import pandas as pd

data = pd.read_csv("artifacts/data/heavy_associated_101.csv.gz")
assignment = pd.read_csv(
    "artifacts/assignments/"
    "heavy_associated_g101_s11_count_balanced.csv.gz"
)
joined = data.merge(
    assignment[["sample_id", "split"]],
    on="sample_id",
    validate="one_to_one",
)
print(joined.groupby("split")["length"].agg(["size", "mean"]))
```

An independent verification pass read back **4,419,878 predictions** and recomputed all **2,880 evaluation-metric rows**. It also checked complete and mutually exclusive sample assignments, component isolation for grouped methods, class coverage, and training-only scaling statistics for the 32 saved models. One representative saved pipeline reproduced its validation, test, and probe predictions exactly. The report is included as `artifacts/integrity_report.json`.

## What to check in your own split

This experiment suggests a practical set of diagnostics:

- **Count samples and components separately**, both overall and per class.
- **Inspect length distributions within classes as well as globally.** Class composition can hide or exaggerate an apparent shift.
- **State the cost of balancing.** A softer length objective may improve one distribution while moving counts away from their targets.
- **Define the evaluation population before comparing scores.** A different test set can change what an accuracy value means.
- **Report infeasible constraints explicitly.** More random seeds cannot make two components cover three disjoint subsets.

Whether length distributions should match depends on the deployment question. Evaluating a familiar length range and deliberately testing a new one are different goals. The useful split is the one that makes that question explicit—and reports the compromises required by the data.

This experiment does not validate real sequence graphs, components containing multiple labels, biological mechanisms, or performance on production data. Its purpose is to make the allocation trade-offs visible in a setting where the assumptions and every reported result can be inspected.
