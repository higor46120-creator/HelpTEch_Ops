# TEMPLATE OFFLINE - NAO APLICAR SEM CONFIGURAR AWS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: helptech-ingress
  namespace: helptech
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/certificate-arn: "${ACM_CERTIFICATE_ARN}"
spec:
  ingressClassName: alb
  rules:
    - host: ${APP_DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
