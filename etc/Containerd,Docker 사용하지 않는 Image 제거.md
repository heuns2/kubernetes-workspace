
- Containerd 기반의 사용하지 않는 Image 삭제 명령어

```
$ crictl ps -a | grep -v Running | awk '{print $1}' | xargs crictl rm && crictl rmi --prune
```

- Docker 기반의 사용하지 않는 Image 삭제 명령어

```
$ docker system prune --filter "until=50h" -f
```
