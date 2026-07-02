# Appendix A: Clinical Categories and definitions
# Appendix B: Data Construction
# Appendix C: Other Summary Stats
# Appendix D: Any Theoretical Derivations and Assumptions Explained


### For showing how my model is isomorphic to assumine zero-profit condition:

The Magic of the Lagrangian DualityLet's imagine the strictest version of a non-profit hospital. They care only about quality (MIPS) and volume, and they do not care about profit at all, except that they legally must break even (Profit $\ge 0$) to keep their doors open.If you set that up as a classic constrained maximization problem, it looks like this:$$ \max \bar{Q}{jt} \quad \text{subject to} \quad \Pi{jt} \ge 0 $$To solve this in microeconomics, you set up a Lagrangian by adding the constraint to the objective function with a multiplier ($\lambda$):$$ \mathcal{L} = \bar{Q}{jt} + \lambda \Pi{jt} $$Now, look at the Master Equation we just built for your paper:$$ W_{jt} = \theta_j \bar{Q}{jt} + (1 - \theta_j) \Pi{jt} $$If you divide our Master Equation by $\theta_j$ (which is just a monotonic transformation and doesn't change the optimization at all), you get:$$ \frac{W_{jt}}{\theta_j} = \bar{Q}{jt} + \left( \frac{1 - \theta_j}{\theta_j} \right) \Pi{jt} $$They are mathematically identical.Your weight term, $\frac{1 - \theta_j}{\theta_j}$, is the exact equivalent of the Lagrange multiplier ($\lambda$) on a zero-profit budget constraint.

# Appendix E: Other Estimation and Regression results (reduced form)
# Appendix F: Other simulations (structural model)