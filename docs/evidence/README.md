# Deployment Evidence

Save screenshots and test-result captures here as Milestones 1 and 2 are verified. Link each item from `../milestone-1-2-delivery.md` and record the date, command/check, outcome, and environment.

## Evidence checklist

- [ ] Local tooling versions and local validation results
- [ ] Terraform formatting, validation, and reviewed plan summary
- [ ] AWS EKS cluster and node readiness during the temporary deployment
- [ ] ECR repositories and deployed image tags
- [ ] Helm lint/render and release status
- [ ] Kubernetes pod, service, PVC (if used), and Ingress health
- [ ] Public endpoint smoke tests for frontend, APIs, and chat/WebSocket where applicable
- [ ] Teardown confirmation and cost-incurring resource cleanup

## Naming and redaction

Use filenames such as `YYYY-MM-DD-m1-eks-cluster.png` or `YYYY-MM-DD-m2-ingress-smoke-test.png`. Include a short caption in the delivery document describing what each screenshot demonstrates.

Before saving or sharing evidence, redact access keys, tokens, passwords, private keys, session cookies, secret values, and personal information. Do not capture terminal scrollback or browser developer tools that expose credentials. Account IDs, cluster names, IPs, and public hostnames should be redacted if the repository or evidence will be public.

Do not commit Terraform state, kubeconfig files, generated credentials, unredacted logs, or application data. Keep evidence limited to what is needed to verify the milestones.
