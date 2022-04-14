# Nginx Ingress Basic Auth 

- Nginx Ingress에 Annotation를 추가하여 해당 Ingress로 통신 시 Basic Auth(기본 인증)을 사용하는 사례에 대하여 기술한 문서입니다.
- 기본적으로 Login Page가 존재하지 않을 경우 임시적인 방안으로 사용 될 수 있습니다.

## 1. Nginx Ingress Basic Auth 사용

### 1.1. Secret 생성
- 사용 할 Auth 파일을 설정 할 Ingress의 Namespace에 생성 합니다.

```
# admin/admin 계정을 사용한다는 가정하에 진행
$ USER=admin; PASSWORD=admin; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> auth

# Auth File 확인
$ cat auth
admin:$apr1$F84tGHeO$h96PZRqPQyHJkMk/Stb630

# Secret 생성
$ kubectl -n monitoring create secret generic basic-auth --from-file=auth

```

### 1.2. Nginx Ingress 설정

- Ingress Annotation에 아래 라인 추가하여 배포

```
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required '
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-type: basic
```

### 1.3. Nginx Ingress 확인

- UI에 접근하여 Basic Auth를 확인하는 창이 출력 되는지 확인

![ingress-basic-auth][ingress-basic-auth]

[ingress-basic-auth]:./images/ingress-basic-auth.PNG


