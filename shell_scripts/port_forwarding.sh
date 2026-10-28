echo "Starting port forwarding for services in the streamingapp namespace..."
kubectl port-forward svc/auth 3001:3001 -n streamingapp
kubectl port-forward svc/streaming 3002:3002 -n streamingapp
kubectl port-forward svc/admin 3003:3003 -n streamingapp
kubectl port-forward svc/chat 3004:3004 -n streamingapp
echo "Port forwarding established. You can access the services at the following URLs:"
echo "Auth Service: http://localhost:3001"
echo "Streaming Service: http://localhost:3002"
echo "Admin Service: http://localhost:3003"
echo "Chat Service: http://localhost:3004"
echo "Press Ctrl+C to stop port forwarding."
echo "Note: Ensure that you have the necessary permissions and that the services are running in the streamingapp namespace."
echo "If you encounter any issues, please check the logs of the respective services for more information."
echo "You can also use 'kubectl get pods -n streamingapp' to check the status of the pods."
echo "------------ port foarding script completed ------------"