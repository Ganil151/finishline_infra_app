# Karpenter YAML Manifests - Part 2

These deliverables represent the dynamic node provisioning expansions strictly utilizing `t3.medium` instances paired perfectly with the `Bottlerocket` architecture constraints via `EC2NodeClass` API integrations.

```yaml
# EC2NodeClass: AWS-Specific Details
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
  labels:
    karpenter.sh/discovery: finishline-infra-app-eks
spec:
  # Constraint Configured: Bottlerocket specific AWS Architecture 
  amiFamily: Bottlerocket
  role: karpenter-node-role
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: finishline-infra-app-eks
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: finishline-infra-app-eks
  tags:
    karpenter.sh/discovery: finishline-infra-app-eks
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 50Gi
        volumeType: gp3
        encrypted: true
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
    httpTokens: required
  detailedMonitoring: false
```

```yaml
# NodePool: Instance and Scaling Delivery Configurations
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
  labels:
    karpenter.sh/discovery: finishline-infra-app-eks
spec:
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        # Constraint Configured: strictly map to t3.medium
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["t3.medium"]
      expireAfter: 720h
  limits:
    cpu: 100
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 30s
  weight: 100
```
