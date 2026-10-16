**Subject: OCN 682 Final Project Proposal – Yang An**

Hi Dr. Silbiger,

Here is my proposal for the final independent project.

**Dataset**
- Monthly U.S. equity factor returns (Fama–French five factors plus momentum, 1963–present) from the Kenneth R. French Data Library.
- Macro series from FRED: the NBER recession indicator, 10-year and 3-month Treasury yields (term spread), and the daily VIX volatility index.

All of these are public and will be downloaded by an R script, so the project is fully reproducible.

**Question / data story**
Do the standard stock-market "risk premia" (market, size, value, profitability, investment, momentum) behave differently in recessions and after periods of market stress than in normal times? And have they weakened since the research documenting them was published? The story is whether these widely used long-run averages are stable or depend on the economic environment.

**Planned outputs**
1. Cumulative returns of each factor over 60 years, with recessions shaded.
2. A table of annualised average returns, Sharpe ratios and t-statistics in recessions vs. expansions.
3. Average returns after low/medium/high VIX months (daily VIX aggregated to monthly and lagged).
4. A many-model workflow (`nest()` + `purrr::map()` + `broom`): one regression per factor of returns on recession and lagged term spread, shown as a coefficient plot.
5. Rolling 10-year premia with publication years marked, plus a before/after-publication table.

**Format**
A Quarto HTML analytical report with cross-referenced figures and tables, citations, callouts, tabsets and code folding, published with GitHub Pages. My presentation will be a Quarto RevealJS deck built from the same processed data.

I'd appreciate any feedback on scope before I start.

Thanks,
Yang An
