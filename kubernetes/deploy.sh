# kubectl delete
kubectl delete deployment,service,pod --all

# ebookmgmt-book
cd ..
cd ebookmgmt-book
mvn package
docker build -t 879772956301.dkr.ecr.ap-southeast-2.amazonaws.com/user18-ebookmgmt-book:v0.1 .
docker push 879772956301.dkr.ecr.ap-southeast-2.amazonaws.com/user18-ebookmgmt-book:v0.1
kubectl apply -f ../kubernetes/ebookmgmt-book.yml

# ebookmgmt-rent
cd ..
cd ebookmgmt-rent
mvn package
docker build -t 879772956301.dkr.ecr.ap-southeast-2.amazonaws.com/user18-ebookmgmt-rent:v0.1 .
docker push 879772956301.dkr.ecr.ap-southeast-2.amazonaws.com/user18-ebookmgmt-rent:v0.1
kubectl apply -f ../kubernetes/ebookmgmt-rent.yml

# ebookmgmt-payment
cd ..
cd ebookmgmt-payment
mvn package
docker build -t 879772956301.dkr.ecr.ap-southeast-2.amazonaws.com/user18-ebookmgmt-payment:v0.1 .
docker push 879772956301.dkr.ecr.ap-southeast-2.amazonaws.com/user18-ebookmgmt-payment:v0.1
kubectl apply -f ../kubernetes/ebookmgmt-payment.yml

# ebookmgmt-dashboard
cd ..
cd ebookmgmt-dashboard
mvn package
docker build -t 879772956301.dkr.ecr.ap-southeast-2.amazonaws.com/user18-ebookmgmt-dashboard:v0.1 .
docker push 879772956301.dkr.ecr.ap-southeast-2.amazonaws.com/user18-ebookmgmt-dashboard:v0.1
kubectl apply -f ../kubernetes/ebookmgmt-dashboard.yml

# ebookmgmt-gateway
cd ..
cd ebookmgmt-gateway
mvn package
docker build -t 879772956301.dkr.ecr.ap-southeast-2.amazonaws.com/user18-ebookmgmt-gateway:v0.1 .
docker push 879772956301.dkr.ecr.ap-southeast-2.amazonaws.com/user18-ebookmgmt-gateway:v0.1
kubectl apply -f ../kubernetes/ebookmgmt-gateway.yml
