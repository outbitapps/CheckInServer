cd /Users/paytondev/Documents/SharedQueueServer
rm -rf Package.resolved
rm -rf .build
cd ../
#ssh root@sq.paytondev.cloud "rm -rf ~/SharedQueueServer/SharedQueueServer; mkdir ~/SharedQueueServer/SharedQueueServer"
ssh root@sq.paytondev.cloud 'cd ~/; rm -rf SharedQueueServer/; mkdir SharedQueueServer/'
scp -r SharedQueueServer/ root@sq.paytondev.cloud:~/SharedQueueServer
scp -r SharedQueueServer/Resources/ root@sq.paytondev.cloud:/home/sqserver/Resources
ssh root@sq.paytondev.cloud 'cd ~/SharedQueueServer/SharedQueueServer; swift package --allow-writing-to-package-directory incv --build-inc; export SKIP_ZERO=1; swift build -c debug; cd .build/x86_64-unknown-linux-gnu/debug; echo $(pwd); echo $(lsof -t -i :8080); kill -9 $(lsof -t -i :8080); rm -rf /home/sqserver/App; cp App /home/sqserver/App; cd /home/sqserver; nohup /home/sqserver/App serve -H "sq.paytondev.cloud" > foo.out 2> foo.err < /dev/null &'
touch SharedQueueServer/Sources/App/version.json
echo "Done! Server should be running now."
