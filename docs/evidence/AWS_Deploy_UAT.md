```

abhis@Bharathgift MINGW64 ~/Harika/CapstoneProject4_EndToEnd/NOV/StreamingAppCapstone ((874455b...))
$ ./scripts/k8s-deploy.sh aws
Updated context arn:aws:eks:ap-south-1:129373676098:cluster/streamingapp-uat-eks in C:\Users\abhis\.kube\config
NAME                                          STATUS   ROLES    AGE    VERSION
ip-106-222-0-22.ap-south-1.compute.internal   Ready    <none>   140m   v1.37.1-eks-9adbfea
deployment "aws-load-balancer-controller" successfully rolled out
About to build and push five images to 129373676098.dkr.ecr.ap-south-1.amazonaws.com, then deploy to EKS cluster streamingapp-uat-eks in ap-south-1.
This does NOT run terraform apply. AWS resources and data may incur cost.
Type deploy to continue: deploy
time="2026-11-23T19:51:45+05:30" level=warning msg="C:\\Users\\abhis\\Harika\\CapstoneProject4_EndToEnd\\NOV\\StreamingAppCapstone\\docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion"
#1 [internal] load local bake definitions
#1 reading from stdin 2.44kB done
#1 DONE 0.0s

#2 [admin internal] load build definition from Dockerfile
#2 transferring dockerfile: 260B done
#2 DONE 0.0s

#3 [streaming internal] load build definition from Dockerfile
#3 transferring dockerfile: 272B done
#3 DONE 0.1s

#4 [chat internal] load build definition from Dockerfile
#4 transferring dockerfile: 257B done
#4 DONE 0.1s

#5 [auth internal] load build definition from Dockerfile
#5 transferring dockerfile: 313B done
#5 DONE 0.1s

#6 [streaming internal] load metadata for docker.io/library/node:18-alpine
#6 DONE 1.0s

#7 [auth internal] load .dockerignore
#7 transferring context: 98B done
#7 DONE 0.1s

#8 [chat internal] load .dockerignore
#8 transferring context: 2B done
#8 DONE 0.1s

#9 [streaming internal] load build context
#9 ...

#10 [auth internal] load build context
#10 transferring context: 675B done
#10 DONE 0.1s

#11 [admin 1/5] FROM docker.io/library/node:18-alpine@sha256:8d6421d663b4c28fd3ebc498332f249011d118945588d0a35cb9bc4b8ca09d9e
#11 resolve docker.io/library/node:18-alpine@sha256:8d6421d663b4c28fd3ebc498332f249011d118945588d0a35cb9bc4b8ca09d9e 0.1s done
#11 DONE 0.1s

#12 [chat internal] load build context
#12 transferring context: 706B done
#12 DONE 0.1s

#13 [chat 4/5] RUN npm install --production
#13 CACHED

#14 [chat 2/5] WORKDIR /app/chatService
#14 CACHED

#15 [chat 3/5] COPY chatService/package*.json ./
#15 CACHED

#16 [auth 3/5] COPY package*.json ./
#16 CACHED

#17 [auth 4/5] RUN apk add --no-cache python3 make g++ libstdc++     && npm install --production     && apk del python3 make g++
#17 CACHED

#18 [auth 2/5] WORKDIR /app
#18 CACHED

#19 [chat 5/5] COPY chatService/. ./
#19 CACHED

#20 [auth 5/5] COPY . .
#20 CACHED

#9 [streaming internal] load build context
#9 ...

#21 [admin internal] load build context
#21 transferring context: 154.43kB 0.1s done
#21 DONE 0.2s

#22 [admin 4/5] RUN npm install --production
#22 CACHED

#23 [admin 3/5] COPY adminService/package*.json ./
#23 CACHED

#24 [admin 2/5] WORKDIR /app/adminService
#24 CACHED

#25 [admin 5/5] COPY adminService/. ./
#25 CACHED

#9 [streaming internal] load build context
#9 ...

#26 [auth] exporting to image
#26 exporting layers done
#26 exporting manifest sha256:f1b1f624c9cb537cad58408310852a0b527f4041e7dee3436ff44707571782a7 done
#26 exporting config sha256:fae22b78713455dc16a202e684a9ef139bf2fd83dda5c171964b870bb83c82fa 0.0s done
#26 exporting attestation manifest sha256:6d910e1dc0b5d93984db018f8be104f60a7c6385ea78723685d19d05131b96a7 0.2s done
#26 exporting manifest list sha256:23b12d3e93519eead5c06ef36862c5dbbc9281f5b0bf5513b0c8c1af4bfc46bb 0.1s done
#26 naming to docker.io/library/streamingappcapstone-auth:latest 0.0s done
#26 unpacking to docker.io/library/streamingappcapstone-auth:latest 0.1s done
#26 DONE 0.6s

#27 [chat] exporting to image
#27 exporting layers done
#27 exporting manifest sha256:9415f666056712c11441771a3ef04ee2e87a4071c1e0422151dfa096df324d25 0.0s done
#27 exporting config sha256:bf70802da49ca37f5c93974c45c069f7819c79dc486d4f40954ebe1fdb5ebca7 0.0s done
#27 exporting attestation manifest sha256:295d03865248c0dbd4a84d6fb0bfedac9e0d950f1ef447c30d9393a9e41446a6 0.2s done
#27 exporting manifest list sha256:c959e3b305981cc8a4dc713c61b112f9507181cfea497f90475fa9c16418daec 0.1s done
#27 naming to docker.io/library/streamingappcapstone-chat:latest 0.0s done
#27 unpacking to docker.io/library/streamingappcapstone-chat:latest 0.1s done
#27 DONE 0.6s

#9 [streaming internal] load build context
#9 ...

#28 [admin] exporting to image
#28 exporting layers done
#28 exporting manifest sha256:4d23e271d2da04479f210b89d61edd67f2cb5f902cd4dcb832d22706641d2289 0.0s done
#28 exporting config sha256:bd7788647ab0c98c0244d61347742700a76ad7d6c33a235723a3dec245d95b65 0.1s done
#28 exporting attestation manifest sha256:7f417766bdb7739d7d4e148b8a1175f52cba345f1101377add43a31408645d08 0.2s done
#28 exporting manifest list sha256:fdc5acc5d2725880e7212b11dcba244977d44825ffb3bb9b09260aa78fbed765 0.1s done
#28 naming to docker.io/library/streamingappcapstone-admin:latest 0.0s done
#28 unpacking to docker.io/library/streamingappcapstone-admin:latest 0.1s done
#28 DONE 0.7s

#9 [streaming internal] load build context
#9 transferring context: 15.79MB 1.0s done
#9 DONE 1.0s

#29 [streaming 4/5] RUN npm install --production
#29 CACHED

#30 [streaming 2/5] WORKDIR /app/streamingService
#30 CACHED

#31 [streaming 3/5] COPY streamingService/package*.json ./
#31 CACHED

#32 [streaming 5/5] COPY streamingService/. ./
#32 CACHED

#33 [streaming] exporting to image
#33 exporting layers done
#33 exporting manifest sha256:e648871f19f3e1021449ea12b5bf512cc27bf1c828f5d80dd57862f4bb698ff0 0.0s done
#33 exporting config sha256:2017efba150752e033b72c602914ef15c424cd062a0dca65509a3665af9427b2 0.0s done
#33 exporting attestation manifest sha256:dcb8057f99d47e148d95208822c3fb1bbcee9edd3928485fbad9efd63d5b746d
#33 exporting attestation manifest sha256:dcb8057f99d47e148d95208822c3fb1bbcee9edd3928485fbad9efd63d5b746d 0.1s done
#33 exporting manifest list sha256:ee8b07f3b50c5ad2efdcde4b4bf5589c7ffa6e6fe5a86fe00be7b985a39538f0
#33 exporting manifest list sha256:ee8b07f3b50c5ad2efdcde4b4bf5589c7ffa6e6fe5a86fe00be7b985a39538f0 0.1s done
#33 naming to docker.io/library/streamingappcapstone-streaming:latest 0.0s done
#33 unpacking to docker.io/library/streamingappcapstone-streaming:latest 0.0s done
#33 DONE 0.4s

#34 [auth] resolving provenance for metadata file
#34 DONE 0.3s

#35 [admin] resolving provenance for metadata file
#35 DONE 0.1s

#36 [chat] resolving provenance for metadata file
#36 DONE 0.2s

#37 [streaming] resolving provenance for metadata file
#37 DONE 0.0s
[+] build 4/4
 ✔ Image streamingappcapstone-auth:latest      Built                                                                                                                      3.5s
 ✔ Image streamingappcapstone-streaming:latest Built                                                                                                                      3.5s
 ✔ Image streamingappcapstone-admin:latest     Built                                                                                                                      3.5s
 ✔ Image streamingappcapstone-chat:latest      Built                                                                                                                      3.5s
[+] Building 1.6s (15/15) FINISHED                                                                                                                       docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                     0.0s
 => => transferring dockerfile: 929B                                                                                                                                     0.0s
 => [internal] load metadata for docker.io/library/nginx:1.27-alpine                                                                                                     0.3s
 => [internal] load metadata for docker.io/library/node:18-alpine                                                                                                        0.0s
 => [internal] load .dockerignore                                                                                                                                        0.0s
 => => transferring context: 93B                                                                                                                                         0.0s
 => [production 1/3] FROM docker.io/library/nginx:1.27-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10                                    0.1s
 => => resolve docker.io/library/nginx:1.27-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10                                               0.1s
 => [internal] load build context                                                                                                                                        0.0s
 => => transferring context: 2.64kB                                                                                                                                      0.0s
 => [build 1/6] FROM docker.io/library/node:18-alpine@sha256:8d6421d663b4c28fd3ebc498332f249011d118945588d0a35cb9bc4b8ca09d9e                                            0.1s
 => => resolve docker.io/library/node:18-alpine@sha256:8d6421d663b4c28fd3ebc498332f249011d118945588d0a35cb9bc4b8ca09d9e                                                  0.1s
 => CACHED [build 2/6] WORKDIR /app                                                                                                                                      0.0s
 => CACHED [build 3/6] COPY package*.json ./                                                                                                                             0.0s
 => CACHED [build 4/6] RUN npm install                                                                                                                                   0.0s
 => CACHED [build 5/6] COPY . .                                                                                                                                          0.0s
 => CACHED [build 6/6] RUN npm run build                                                                                                                                 0.0s
 => CACHED [production 2/3] COPY --from=build /app/build /usr/share/nginx/html                                                                                           0.0s
 => CACHED [production 3/3] COPY nginx.conf /etc/nginx/conf.d/default.conf                                                                                               0.0s
 => exporting to image                                                                                                                                                   0.3s
 => => exporting layers                                                                                                                                                  0.0s
 => => exporting manifest sha256:93fcdb14a9208a38a6516a799561c5f0ea3f3204d5b5bd6475ed58f64e6f9857                                                                        0.0s
 => => exporting config sha256:f3f620c601c9d8c4f1c81a216f5e5773de352218feb9c6a08ee926cc7a9cdb70                                                                          0.0s
 => => exporting attestation manifest sha256:116d51f6618cfc9c9b88dd5432e67bce35ba014014c8c0e0f4c4e5b0455cae61                                                            0.1s
 => => exporting manifest list sha256:49c337d7c4a6f0a593d74d0df58d66bd96426785de27f6f3bb1ee96c8ce79c4e                                                                   0.0s
 => => naming to docker.io/library/streamingapp-frontend:aws-874455b-20261123142145                                                                                      0.0s
 => => unpacking to docker.io/library/streamingapp-frontend:aws-874455b-20261123142145                                                                                   0.0s

 2 warnings found (use docker --debug to expand):
 - SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data (ARG "REACT_APP_AUTH_API_URL") (line 10)
 - SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data (ENV "REACT_APP_AUTH_API_URL") (line 17)

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/iz4jefbfj6bo9xt02tqyc5h6s

WARNING! Your credentials are stored unencrypted in 'C:\Users\abhis\.docker\config.json'.
Configure a credential helper to remove this warning. See
https://docs.docker.com/go/credential-store/

Login Succeeded
The push refers to repository [129373676098.dkr.ecr.ap-south-1.amazonaws.com/streamingapp-uat-auth]
25ff2da83641: Layer already exists 
6922a592f54c: Layer already exists 
af53539fa6cd: Pushed 
8170333b0ade: Layer already exists 
1e5a4c89cee5: Layer already exists 
6e20017a8d3d: Layer already exists 
f18232174bc9: Layer already exists 
dd71dde834b5: Layer already exists 
eb530d8ad937: Layer already exists 
874455b-20261123142145: digest: sha256:23b12d3e93519eead5c06ef36862c5dbbc9281f5b0bf5513b0c8c1af4bfc46bb size: 856
The push refers to repository [129373676098.dkr.ecr.ap-south-1.amazonaws.com/streamingapp-uat-streaming]
f18232174bc9: Layer already exists 
a6c4262e0df4: Layer already exists 
25ff2da83641: Layer already exists 
e4eb9651aec9: Pushed 
f62940b52330: Layer already exists 
1e5a4c89cee5: Layer already exists 
4d8dc50fca9e: Layer already exists 
dd71dde834b5: Layer already exists 
53c09e3fd132: Layer already exists 
874455b-20261123142145: digest: sha256:ee8b07f3b50c5ad2efdcde4b4bf5589c7ffa6e6fe5a86fe00be7b985a39538f0 size: 856
The push refers to repository [129373676098.dkr.ecr.ap-south-1.amazonaws.com/streamingapp-uat-admin]
0eff7ecaf01b: Layer already exists 
25ff2da83641: Layer already exists 
0e0cda10adf4: Layer already exists 
05301574784c: Layer already exists 
870f33686fb7: Pushed 
1e5a4c89cee5: Layer already exists 
f18232174bc9: Layer already exists 
dd71dde834b5: Layer already exists 
f45beb961d28: Layer already exists 
874455b-20261123142145: digest: sha256:fdc5acc5d2725880e7212b11dcba244977d44825ffb3bb9b09260aa78fbed765 size: 856
The push refers to repository [129373676098.dkr.ecr.ap-south-1.amazonaws.com/streamingapp-uat-chat]
97b81b040dd6: Pushed 
f18232174bc9: Layer already exists 
dd71dde834b5: Layer already exists 
1e5a4c89cee5: Layer already exists 
25ff2da83641: Layer already exists 
eada545abf54: Layer already exists 
3815ce68c903: Layer already exists 
1928bb50c2d3: Layer already exists 
335fe94bec4f: Layer already exists 
874455b-20261123142145: digest: sha256:c959e3b305981cc8a4dc713c61b112f9507181cfea497f90475fa9c16418daec size: 856
The push refers to repository [129373676098.dkr.ecr.ap-south-1.amazonaws.com/streamingapp-uat-frontend]
34a64644b756: Layer already exists 
197eb75867ef: Layer already exists 
32fb3e62eb11: Layer already exists 
f18232174bc9: Layer already exists 
5fd8d1880a32: Layer already exists 
d7e507024086: Layer already exists 
81bd8ed7ec67: Layer already exists 
61ca4f733c80: Layer already exists 
39c2ddfd6010: Layer already exists 
b464cfdf2a63: Layer already exists 
d2c49fbb6064: Pushed 
874455b-20261123142145: digest: sha256:49c337d7c4a6f0a593d74d0df58d66bd96426785de27f6f3bb1ee96c8ce79c4e size: 856
namespace/streamingapp-uat unchanged
Release "streamingapp-uat" does not exist. Installing it now.
NAME: streamingapp-uat
LAST DEPLOYED: Mon Nov 23 19:52:06 2026
NAMESPACE: streamingapp-uat
STATUS: deployed
REVISION: 1
TEST SUITE: None
Release "streamingapp-uat" has been upgraded. Happy Helming!
NAME: streamingapp-uat
LAST DEPLOYED: Mon Nov 23 19:52:36 2026
NAMESPACE: streamingapp-uat
STATUS: deployed
REVISION: 2
TEST SUITE: None
deployment.apps/streamingapp-uat-admin condition met
deployment.apps/streamingapp-uat-auth condition met
deployment.apps/streamingapp-uat-chat condition met
deployment.apps/streamingapp-uat-frontend condition met
deployment.apps/streamingapp-uat-mongo condition met
deployment.apps/streamingapp-uat-streaming condition met
AWS deployment complete. Environment: uat; image tag: 874455b-20261123142145
Ingress: http://k8s-streamin-streamin-c7ff46018b-1844002002.ap-south-1.elb.amazonaws.com
NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/streamingapp-uat-admin       1/1     1            1           76s
deployment.apps/streamingapp-uat-auth        1/1     1            1           76s
deployment.apps/streamingapp-uat-chat        1/1     1            1           76s
deployment.apps/streamingapp-uat-frontend    1/1     1            1           76s
deployment.apps/streamingapp-uat-mongo       1/1     1            1           76s
deployment.apps/streamingapp-uat-streaming   1/1     1            1           76s

NAME                                              READY   STATUS    RESTARTS   AGE
pod/streamingapp-uat-admin-764c4574ff-p68rt       1/1     Running   0          45s
pod/streamingapp-uat-auth-99dfd577d-9wvqx         1/1     Running   0          45s
pod/streamingapp-uat-chat-7bfff9664b-vtf9s        1/1     Running   0          45s
pod/streamingapp-uat-frontend-6666d8779b-zq5nc    1/1     Running   0          76s
pod/streamingapp-uat-mongo-68947679cf-th9vn       1/1     Running   0          76s
pod/streamingapp-uat-streaming-65f79f5b84-jl82f   1/1     Running   0          45s

NAME                                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE
service/streamingapp-uat-admin       ClusterIP   10.100.173.235   <none>        3003/TCP    76s
service/streamingapp-uat-auth        ClusterIP   10.100.30.152    <none>        3001/TCP    76s
service/streamingapp-uat-chat        ClusterIP   10.100.245.145   <none>        3004/TCP    76s
service/streamingapp-uat-frontend    ClusterIP   10.100.146.136   <none>        80/TCP      76s
service/streamingapp-uat-mongo       ClusterIP   10.100.20.131    <none>        27017/TCP   76s
service/streamingapp-uat-streaming   ClusterIP   10.100.143.55    <none>        3002/TCP    76s

NAME                                                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/streamingapp-uat-mongo-data   Bound    pvc-a3be3777-21e0-4a21-9867-4d68abcca901   5Gi        RWO            gp3            <unset>                 76s

NAME                                         CLASS   HOSTS   ADDRESS                                                                    PORTS   AGE
ingress.networking.k8s.io/streamingapp-uat   alb     *       k8s-streamin-streamin-c7ff46018b-1844002002.ap-south-1.elb.amazonaws.com   80      76s

```

> <img width="1541" height="987" alt="image" src="https://github.com/user-attachments/assets/30855013-e9a1-4906-b832-d2f626e3b128" />

> <img width="1794" height="917" alt="image" src="https://github.com/user-attachments/assets/51960a37-20e7-47a0-8a17-f16f2e54249a" />

> <img width="1694" height="956" alt="image" src="https://github.com/user-attachments/assets/829aaa19-9062-4a42-b04c-ac5a13ede0e8" />

> <img width="1367" height="810" alt="image" src="https://github.com/user-attachments/assets/4a74067a-76f3-4a0e-ac0a-61f9bbadd2f5" />

> <img width="1320" height="557" alt="image" src="https://github.com/user-attachments/assets/84498c50-be59-443f-bb86-ddc210bef330" />

> <img width="1671" height="721" alt="image" src="https://github.com/user-attachments/assets/6e4d88cd-c3b2-42a8-9734-82ac3498e280" />

> <img width="1731" height="560" alt="image" src="https://github.com/user-attachments/assets/e2354fd2-2e62-4840-8fe2-b451c5133f07" />

>
>


```
