@echo off
echo ============================================================
echo AWS SSM Port Forwarding: radp DB primary
echo ============================================================
echo Local Port: 5176 ^> Instance: i-0b255c2071776bbff
echo AWS Profile: APD-Editorial-Prod
echo Region: us-east-1
echo ============================================================
aws ssm start-session --target i-0b255c2071776bbff --document-name AWS-StartPortForwardingSession --parameters portNumber=22,localPortNumber=5176 --region us-east-1 --profile APD-Editorial-Prod
pause
