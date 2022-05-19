
- Context가 많이 질 경우 그 중 한개를 뽑아 사용자에게 전달 할 경우 사용

```
$ kubectl config get-contexts
CURRENT   NAME                             CLUSTER         AUTHINFO            NAMESPACE
          test1                            cluster.local   test1               test1
          test2                            cluster.local   test2               test2
*         kubernetes-admin@cluster.local   cluster.local   kubernetes-admin


$ kubectl config view --context=test1 --minify --flatten
$ kubectl config view --context=test2 --minify --flatten
```
