# 参考情報
ハードウェア要件
https://rancher.com/docs/rancher/v2.x/en/installation/requirements/

Rancher2.1でKubernetes環境を構築する
https://dev.classmethod.jp/etc/rancher2-0-kubernetes-setup/

安いクラウド環境でRancherOS / Kubernetesを使って勉強用クラスタを作る
https://qiita.com/tatsurou313/items/5e3d94ebb809f114aa53

VagrantでRancher+Kubernetes環境を作成する #1
https://github.com/aokabin/rancher-practice/issues/1

RancherOS Vagrant
https://github.com/rancher/os-vagrant

coreos-vagrant
https://github.com/coreos/coreos-vagrant

Rancherのカスタムカタログの作成
https://thinkit.co.jp/article/16095

How to convert your web application to a Helm chart
https://developer.ibm.com/tutorials/convert-sample-web-app-to-helmchart/

DockerのプライベートレジストリとしてGitLabのContainerRegistryを使う
https://qiita.com/suesan/items/7fde092df0c5f9cc48d6

CoreOSをVirtualBox上の仮想マシンへVagrantなしでインストールする
https://fight-tsk.blogspot.com/2015/03/coreosvirtualboxvagrant.html





# RancherOSで構築
# 以下からvhdをDLしてVirtualBoxで既にある仮想HDからVM作成する
https://github.com/rancher/os

※UUIRエラーが出たら以下を実行。
VBoxManage internalcommands sethduuid ~/VirtualBox\ VMs/RancherOSWorker/rancheros-aliyun.vhd

sudo passwd rancher

sudo vi /var/lib/rancher/conf/cloud-config.d/user_config.yml

# rancherの起動
ssh rancher@192.168.57.100
sudo docker run -d --restart=unless-stopped -p 10080:80 -p 10443:443 rancher/rancher:latest

# クラスター「php」で「ノード」タブを選択し、「クラスターの編集」からworkerノードを追加する
※クラスターの編集画面最下の以下のコマンドをコピーし、vagrant「woker」で実行する
ノードロール：Worker
ノードアドレス（パブリックIP）（※）：192.168.2.210
ノードアドレス（プライベートIP）（※）10.0.2.120

（※）「詳細オプションを表示」リンクをクリックすると設定項目が出てくる

sudo docker run -d --privileged --restart=unless-stopped --net=host -v /etc/kubernetes:/etc/kubernetes -v /var/run:/var/run rancher/rancher-agent:v2.3.5 --server https://192.168.57.100:10443 --token czddjqtkx5vhpztxp4n9lzhdwnwr92stt98gvtffl49qcx4kvzqhxm --ca-checksum 824ba5980374932059e90288dfa89270305c76c47b3f0afa2c06f615c718f625 --address 192.168.2.210 --internal-address 10.0.2.120 --etcd --controlplane --worker



# helm chartのデバッグ
helm install --dry-run --debug ./postgresql  
helm install --dry-run --debug ./gitlab  
helm install --dry-run --debug ./gitlab-runner  
helm install --dry-run --debug ./bind  

# MySQLログイン
mysql -uroot -proot

# gitlabのcontainer registoryの設定
https://www.kinakomotitti.net/entry/2018/11/25/155003

# 以下をphpプロジェクトのkubectlで実行。
mkdir -p /tmp/ssl
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /tmp/ssl/registry.example.com.key -x509 -days 3650 \
    -out /tmp/ssl/registry.example.com.crt \
    -subj "/C=JP/ST=Hyogo/L=Kobe-shi/O=DIGITAL ALLIANCE HOLDINGS CO.,LTD/OU=Solution Division/CN=registry.example.com/emailAddress=hatakeyama@d-a.co.jp"
kubectl create secret tls secret-ssl-regist \
  --cert /tmp/ssl/registry.example.com.crt --key /tmp/ssl/registry.example.com.key
# 以下コマンドの出力結果をコピーし、gitlabのsecretファイルとして作成（namespace、selfLink、creationTimestamp、resourceVersion、uidは削除）
kubectl get secrets secret-ssl-regist -o yaml
kubectl delete secret secret-ssl-regist

openssl req -newkey rsa:4096 -nodes -sha256 -keyout /tmp/ssl/gitlab.example.com.key -x509 -days 3650 \
    -out /tmp/ssl/gitlab.example.com.crt \
    -subj "/C=JP/ST=Hyogo/L=Kobe-shi/O=DIGITAL ALLIANCE HOLDINGS CO.,LTD/OU=Solution Division/CN=gitlab.example.com/emailAddress=hatakeyama@d-a.co.jp"
kubectl create secret tls secret-ssl-gitlab \
  --cert /tmp/ssl/gitlab.example.com.crt --key /tmp/ssl/gitlab.example.com.key
# 以下コマンドの出力結果をコピーし、gitlabのsecretファイルとして作成（namespace、selfLink、creationTimestamp、resourceVersion、uidは削除）
kubectl get secrets secret-ssl-gitlab -o yaml
kubectl delete secret secret-ssl-gitlab

rm -rf /tmp/ssl

echo "127.0.0.1 registry.example.com" >> /etc/hosts
ln -s /etc/gitlab/ssl/registry.example.com.crt /usr/share/ca-certificates/registry.example.com.crt
ln -s /etc/gitlab/ssl/registry.example.com.crt /etc/ssl/certs/registry.example.com.crt

# プライベートのcontainre registoryからイメージPULLするためのsecret作成
docker login registry.example.com -u hatake_t14@hotmail.com -p ffffffff
cat ~/.docker/config.json
vi ./dockerconfig.json
kubectl create secret generic secret-registry \
    --from-file=.dockerconfigjson=./dockerconfig.json \
    --type=kubernetes.io/dockerconfigjson
# 以下コマンドの出力結果をコピーし、gitlabのsecretファイルとして作成（namespace、selfLink、creationTimestamp、resourceVersion、uidは削除）
kubectl get secrets secret-registry -o yaml
kubectl delete secret secret-registry 
rm -rf ./dockerconfig.json

# gitlabへのdocker push
# TEST_IMAGE: //hello_hapi:$CI_COMMIT_REF_NAME
# RELEASE_IMAGE: //hello_hapi:latest
scp -r /Users/tadanobu/Documents/Kubernetes/rancher-mac/rancher-catalog rancher@192.168.57.100:/home/rancher/rancher-catalog
ssh rancher@192.168.2.200 
vi /etc/docker/daemon.json
{
  "insecure-registries" : ["registry.example.com","registry.example.com:443","registry.example.com:4567"]
}
sudo shutdown now -h

# gitコマンドをrancherosで使えるようにする
vi ~/.gitconfig
[user]
        email = hatake_t14@hotmail.com
        name = Tadanobu Hatakeyama
[http]
        sslVerify = false

echo "alias git='docker run --add-host=gitlab.example.com:192.168.2.210 -v /home/rancher/.gitconfig:/root/.gitconfig -ti --rm -v $(pwd):/git bwits/docker-git-alpine'" >> ~/.bash_profile
source ~/.bash_profile 

# gitlabログイン  
cd /home/rancher
docker login registry.example.com -u hatake_t14@hotmail.com -p ffffffff

# イメージbuild push  
mkdir /home/rancher/rancher-catalog
cd /home/rancher
git clone https://github.com/take-t14/rancher-catalog.git ./rancher-catalog
docker build -t registry.example.com/hatake_t14/php/bind:latest ./rancher-catalog/bind/Docker
docker push registry.example.com/hatake_t14/php/bind:latest

docker build --add-host=gitlab.example.com:192.168.2.210 -t registry.example.com/hatake_t14/php/apache-php:latest ./rancher-catalog/apache-php/docker push registry.example.com/hatake_t14/php/apache-php:latest

docker build --add-host=gitlab.example.com:192.168.2.210 -t registry.example.com/hatake_t14/php/nuxt:latest ./rancher-catalog/nuxt/Docker
docker push registry.example.com/hatake_t14/php/nuxt:latest

mkdir /home/rancher/php
cd /home/rancher
git clone -b develop https://gitlab.example.com/hatake_t14/php.git ./php
docker build --add-host=gitlab.example.com:192.168.2.210 -t registry.example.com/hatake_t14/php/apache-php-base:latest ./php/apache-php/Docker/1.basebuild
docker push registry.example.com/hatake_t14/php/apache-php-base:latest

mkdir /home/rancher/php-helm
cd /home/rancher
git clone -b develop https://gitlab.example.com/hatake_t14/php-helm.git ./php-helm
docker build --add-host=gitlab.example.com:192.168.2.210 -t registry.example.com/hatake_t14/php/cypress-test:latest /home/rancher/php-helm/apache-php/Docker/0.cypressBuild
docker push registry.example.com/hatake_t14/php/cypress-test:latest
docker build --add-host=gitlab.example.com:192.168.2.210 -t registry.example.com/hatake_t14/php-helm/cypress-test:latest /home/rancher/php-helm/apache-php/Docker/0.cypressBuild
docker push registry.example.com/hatake_t14/php-helm/cypress-test:latest

# イメージpull  
docker pull registry.example.com/hatake_t14/php/bind:latest
docker pull registry.example.com/hatake_t14/php/apache-php:latest
docker pull registry.example.com/hatake_t14/php/nuxt:latest
docker pull registry.example.com/hatake_t14/php/cypress-test:latest
# イメージ起動  
docker run -it --name nuxt registry.example.com/hatake_t14/php/nuxt:latest /bin/bash
docker run -it --name cypress-test registry.example.com/hatake_t14/php-helm/cypress-test:latest /bin/bash


# gitlabのDNS登録
# kubectl edit cm coredns -n kube-system
kubectl get -n kube-system cm/coredns --export -o yaml > /tmp/coredns_cm.yaml
vi /tmp/coredns_cm.yaml
        ready
        # 以下追加
        hosts {
          192.168.2.210 gitlab.example.com
          192.168.2.210 registry.example.com
          fallthrough
        }
        # ここまで
        kubernetes cluster.local in-addr.arpa ip6.arpa {
kubectl replace -n kube-system -f /tmp/coredns_cm.yaml

# jenkisのCPU、メモリ調整（できなかった）
kubectl get clusterrole create-ns -o yaml > /tmp/create-ns.yaml
kubectl get clusterrole project-member-promoted -o yaml > /tmp/project-member-promoted.yaml
kubectl get clusterrole p-5crxt-namespaces-edit -o yaml > /tmp/p-5crxt-namespaces-edit.yaml
cp /tmp/create-ns.yaml /tmp/create-ns.yaml_org
cp /tmp/project-member-promoted.yaml /tmp/project-member-promoted.yaml_org
cp /tmp/p-5crxt-namespaces-edit.yaml /tmp/p-5crxt-namespaces-edit.yaml_org
vi /tmp/create-ns.yaml
vi /tmp/project-member-promoted.yaml
vi /tmp/p-5crxt-namespaces-edit.yaml
kubectl apply -f /tmp/create-ns.yaml
kubectl apply -f /tmp/project-member-promoted.yaml
kubectl apply -f /tmp/p-5crxt-namespaces-edit.yaml

# gitlab runnerで「dial tcp: lookup registry.example.com on 8.8.8.8:53: no such host」が出た場合
docker login registry.example.com -u hatake_t14@hotmail.com -p ffffffff
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Error response from daemon: Get https://registry.example.com/v2/: dial tcp: lookup registry.example.com on 8.8.8.8:53: no such host
workerと、gitlabノードに、sudo vi /etc/hostsで「192.168.2.210 gitlab.example.com registry.example.com」追加。

# gitlab runnerで「x509: certificate signed by unknown authority」が出た場合
docker login registry.example.com -u hatake_t14@hotmail.com -p ffffffff
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Error response from daemon: Get https://registry.example.com/v2/: x509: certificate signed by unknown authority
sudo vi /etc/docker/daemon.json
{
  "insecure-registries" : ["registry.example.com","registry.example.com:443","registry.example.com:4567"]
}
sudo shutdown now -h

# rancher pipelineの実行で「CRLfile: none」が出た場合
# stderr: fatal: unable to access 'https://gitlab.example.com/hatake_t14/php-helm.git/': server certificate verification failed. CAfile: /etc/ssl/certs/ca-certificates.crt CRLfile: none
php → Default → ツール → パイプライン → Edit cacertsで、gitlab.example.com.crtの中身を貼り付けて保存する。

# rancher pipelineでgit pushしてもパイプラインがトリガーされない場合
# https://taikii.net/posts/2018/11/gitlab-disable-requests-to-the-local-network-from-hooks/
1.gitlabへroot/ffffffffでログインする
2.Admin Area（左上のスパムマーク） → Setting → Network → Outbound requests
　「Allow requests to the local network from web hooks and services」にチェックを入れる。
3.rancher pipelineの設定を一旦解除し、再度設定する。
4.gitlabのプロジェクト →  設定　→　インテグレーションで、Webhooksが設定されていることを確認。

# VirtualBoxでCoreOS構築(rancher、worker、gitlabの３端末作成)
※　OSのisoファイルを以下からDLしておく
https://github.com/rancher/os/releases/

・Linux、Other Linux x64
・ストレージ→コントローラ：IDE→DVDアイコン→iso設定→rancheros.iso
※Live CD/DVDをチェックON
・VirtualBox→設定→ネットワークでNatnetwork（10.0.2.0/24、DHCPサポートON、IPv6サポートOFF）を追加
・ネットワーク→タブ1：ブリッジアダプター
・起動
・ifconfig -a > /tmp/ifconfig.log && less /tmp/ifconfig.log  
・ホストオンリー側のNIC(enp0s8)のIPアドレスとネットマスクをメモ(※以下の説明では192.168.2.124/24と仮定)
・sudo passwd rancher  
※パスワードは「f」
・ホストのターミナルからssh rancher@192.168.2.124で接続
・sudo -s
※パスワードは「f」
・【ホスト】ssh-keygen -t rsa
・【ホスト】cat ~/.ssh/id_rsa.pub
※出力した文字列をrancheros-rancher.ymlへコピペしておく(ssh-authorized-keysに使用)
・vi cloud-config.yml
※config.ymlをベースに、上記値を当てはめて設定ファイルを作成
・sudo ros install -c cloud-config.yml -d /dev/sda
※yes→Nと解答
・shutdown now -h
・コントローラー:IDE>coreos_production_iso_image.isoを選択し、仮想ドライブからディスクを除去
・起動
・sudo systemctl restart systemd-networkd

# rancherの起動
ssh core@192.168.2.200
sudo docker run -d --restart=unless-stopped -p 10080:80 -p 10443:443 -e GIT_SSL_NO_VERIFY=true --add-host=gitlab.example.com:192.168.2.210 rancher/rancher:latest

# gitlabのIP修正(192.168.2.200でやる)
if [ "" = "`docker exec -it d1f25706d9cb cat /etc/hosts | grep 192.168.2.200`" ] ; then echo "not need setting"; else docker exec -it d1f25706d9cb /bin/bash -c 'cp /etc/hosts /tmp/hosts && sed -i "s/192\.168\.2\.200/192\.168\.2\.210/" /tmp/hosts && cp /tmp/hosts /etc/hosts'; fi

# ブラウザでhttps://192.168.2.200/へアクセス

# クラスター「php」を「カスタム」で作成する
クラスター名：php
ノードロール：etcd、Control、Worker
ノードアドレス（パブリックIP）（※）：192.168.2.220
ノードアドレス（プライベートIP）（※）：192.168.2.220

（※）「詳細オプションを表示」リンクをクリックすると設定項目が出てくる

# etcd、Control、Workerのノードを追加する
※以下のコピーしたコマンドを、vagrant「control」で実行する
sudo docker run -d --privileged --restart=unless-stopped --net=host -v /etc/kubernetes:/etc/kubernetes -v /var/run:/var/run rancher/rancher-agent:v2.3.5 --server https://192.168.2.200:10443 --token f75j492hwrf226xkdjt8d768kz5dvgfbxbbm9klxbljlj7zdbx5zvg --ca-checksum 1a726fcf6722af6f10f09dda322694db3841cfdd4d3418f957f198451e31ee65 --address 192.168.2.220 --internal-address 192.168.2.220 --etcd --controlplane --worker

sudo docker run -d --privileged --restart=unless-stopped --net=host -v /etc/kubernetes:/etc/kubernetes -v /var/run:/var/run rancher/rancher-agent:v2.3.5 --server https://192.168.2.200:10443 --token f75j492hwrf226xkdjt8d768kz5dvgfbxbbm9klxbljlj7zdbx5zvg --ca-checksum 1a726fcf6722af6f10f09dda322694db3841cfdd4d3418f957f198451e31ee65 --node-name gitlab --address 192.168.2.210 --internal-address 192.168.2.210 --worker

# 【参考】gitlabのdockerで起動する際のコマンド
# sudo docker run --detach \
#     --hostname gitlab.example.com \
#     --publish 8443:443 --publish 8080:80 --publish 22:22 \
#     --name gitlab \
#     --restart always \
#     --volume /Users/tadanobu/docker/gitlab/config:/etc/gitlab \
#     --volume /Users/tadanobu/docker/gitlab/logs:/var/log/gitlab \
#     --volume /Users/tadanobu/docker/gitlab/data:/var/opt/gitlab \
#     gitlab/gitlab-ce:latest
# 
# sudo docker run --detach \
#     --hostname gitlab.example.com \
#     --publish 8443:443 --publish 8080:80 --publish 8022:22 \
#     --name gitlab \
#    --restart always \
#     --volume /etc:/etc \
#     --volume /var:/var \
#     gitlab/gitlab-ce:latest

# rancher → GitLab パイプライン連携 (509対策。VM「rancher」で実行（途中Dockerコンテナ「rancher」に接続して作業する）)
docker ps -a
# CONTAINER ID        IMAGE                    COMMAND             CREATED             STATUS              PORTS                                           NAMES
# eec751d58ee7        rancher/rancher:latest   "entrypoint.sh"     7 hours ago         Up 6 minutes        0.0.0.0:10080->80/tcp, 0.0.0.0:10443->443/tcp   awesome_lichterman
vi /tmp/gitlab.example.com.crt
docker cp /tmp/gitlab.example.com.crt eec751d58ee7:/tmp/gitlab.example.com.crt
docker exec -it eec751d58ee7 /bin/bash
mkdir -p /etc/rancher/ssl
mv /tmp/gitlab.example.com.crt /etc/rancher/ssl/gitlab.example.com.crt
ln -s /etc/rancher/ssl/gitlab.example.com.crt /etc/ssl/certs/gitlab.example.com.crt
mkdir /usr/share/ca-certificates/extra
ln -s /etc/rancher/ssl/gitlab.example.com.crt /usr/share/ca-certificates/extra/gitlab.example.com.crt
echo "extra/gitlab.example.com.crt" >> /etc/ca-certificates.conf
update-ca-certificates
exit
docker stop eec751d58ee7
docker start eec751d58ee7


curl -O https://get.helm.sh/helm-v3.1.0-linux-arm64.tar.gz
tar -zxvf helm-v3.1.0-linux-arm64.tar.gz


kubectl get namespace  
kubectl config get-contexts  
kubectl config set-context Default --namespace=gitlab-ce  
kubectl get pods
kubectl get pv 
kubectl get pvc 
kubectl exec -it gitlab-ce-gitlab-ce-0 /bin/bash

# 全podの状態確認
kubectl get pods --all-namespaces -o wide  

# 全podの状態詳細確認
kubectl describe pods --all-namespaces

# 1つのpodの状態詳細確認
kubectl describe pods gitlab-ce-gitlab-ce-0 -n gitlab-ce
kubectl describe ingress gitlab-ce-gitlab-ce -n gitlab-ce

# crd復旧
kubectl -n kube-system get pod | grep -E '^NAME|calico' 
kubectl get crd
kubectl get crd -o yaml > crd-backup.yaml  
kubectl apply -f https://raw.githubusercontent.com/projectcalico/libcalico-go/master/test/crds.yaml
kubectl -n kube-system get pod -l k8s-app=calico-node  
kubectl -n kube-system delete pod -l k8s-app=calico-node  
kubectl -n kube-system get pod -l k8s-app=calico-typha  
kubectl -n kube-system delete pod -l k8s-app=calico-typha  

kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml

/usr/local/bin/kubectl --kubeconfig ../kubeconfig get namespace
/usr/local/bin/kubectl --kubeconfig ../kubeconfig config get-contexts  
























# vagrant構築
cd /Users/tadanobu/Documents/Kubernetes/rancher-mac
mkdir ./rancher
git clone https://github.com/coreos/coreos-vagrant/ ./rancher

mkdir ./control
git clone https://github.com/coreos/coreos-vagrant/ ./control

mkdir ./worker
git clone https://github.com/coreos/coreos-vagrant/ ./worker

cd ./rancher
vi Vagrantfile
※以下編集を実施
◆「# Defaults for config options defined in CONFIG」の次の行へ以下を追記
$ip_base_num = 100

◆$instance_name_prefix = "core"を以下の様に変更
$instance_name_prefix = "rancher"

◆ip = "172.17.8.#{i+100}"を以下の様に変更
ip = "172.17.8.#{i+$ip_base_num}"

vagrant up

cd ../control
◆「# Defaults for config options defined in CONFIG」の次の行へ以下を追記
$ip_base_num = 101

◆$instance_name_prefix = "core"を以下の様に変更
$instance_name_prefix = "control"

◆ip = "172.17.8.#{i+100}"を以下の様に変更
ip = "172.17.8.#{i+$ip_base_num}"

vagrant up

cd ../worker
◆「# Defaults for config options defined in CONFIG」の次の行へ以下を追記
$ip_base_num = 102

◆$instance_name_prefix = "core"を以下の様に変更
$instance_name_prefix = "worker"

◆ip = "172.17.8.#{i+100}"を以下の様に変更
ip = "172.17.8.#{i+$ip_base_num}"

vagrant up

# Rancherサーバーの起動
cd ../rancher
vagrant ssh

sudo docker run -d --restart=unless-stopped -p 10080:80 -p 10443:443 rancher/rancher:latest

# ブラウザでhttps://172.17.8.101/へアクセス

# クラスター「php」を「カスタム」で作成する
クラスター名：php
ノードロール：etcd、Control
ノードアドレス（パブリックIP）（※）：192.168.2.210
ノードアドレス（プライベートIP）（※）192.168.2.210

（※）「詳細オプションを表示」リンクをクリックすると設定項目が出てくる

# etcd、Controlのノードを追加する
※以下のコピーしたコマンドを、vagrant「control」で実行する
sudo docker run -d --privileged --restart=unless-stopped --net=host -v /etc/kubernetes:/etc/kubernetes -v /var/run:/var/run rancher/rancher-agent:v2.3.5 --server https://192.168.57.100:10443 --token j5njlsxns6mbjcrcmpdxb4xkvm7hrdnb4qkfdphdb5qcd25n7s2lnz --ca-checksum 9b2e3d48335fda8f731b70e747f206ef60bc41d15b58dc9ad35c66bd77e1e3e2 --address 192.168.2.210 --internal-address 192.168.2.210 --etcd --controlplane

# クラスター「php」で「ノード」タブを選択し、「クラスターの編集」からworkerノードを追加する
※クラスターの編集画面最下の以下のコマンドをコピーし、vagrant「woker」で実行する
ノードロール：Worker
ノードアドレス（パブリックIP）（※）：192.168.2.200
ノードアドレス（プライベートIP）（※）192.168.2.200

（※）「詳細オプションを表示」リンクをクリックすると設定項目が出てくる

sudo docker run -d --privileged --restart=unless-stopped --net=host -v /etc/kubernetes:/etc/kubernetes -v /var/run:/var/run rancher/rancher-agent:v2.3.5 --server https://172.17.8.101 --token n2fn6qg49k7shdjncf89nxt69lgnbs8rcvfl5828v29fbd5pstpsd4 --ca-checksum dc50685e6d5dd4262c82dfae486834b493649e234daaa2446c39ac3377f43560 --address 192.168.2.200 --worker


sudo docker run --detach \
    --hostname gitlab.example.com \
    --publish 8443:443 --publish 8080:80 --publish 22:22 \
    --name gitlab \
    --restart always \
    --volume /Users/tadanobu/docker/gitlab/config:/etc/gitlab \
    --volume /Users/tadanobu/docker/gitlab/logs:/var/log/gitlab \
    --volume /Users/tadanobu/docker/gitlab/data:/var/opt/gitlab \
    gitlab/gitlab-ce:latest

docker ps -a
docker stop 6a58fb219e9d
docker commit hubot1 hubot:tubone























Rancherチュートリアル：デスクトップでRancher 2.0を実行する方法
https://rancher.com/blog/2018/2018-05-18-how-to-run-rancher-2-0-on-your-desktop/

Docker設定
CPU：最低2以上、4以上推奨
メモリ：最低4GB、8GB以上推奨
Swap：デフォルト(1GB)
Disk image max sizes：96GB以上

Kubernetesを有効にする

MacにHelmのコマンドラインツールをインストール
brew install helm@2
echo 'export PATH="/usr/local/opt/helm@2/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

クラスターでHelmを初期化する
kubectl -n kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller --wait

入力コントローラーを追加する
helm install stable/nginx-ingress --name ingress-nginx --namespace ingress-nginx --wait

Cert-Managerをインストールする
helm install stable/cert-manager --name cert-manager --namespace kube-system --wait --version v0.5.2


Rancherのインストール
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update
helm install rancher-latest/rancher --name rancher --namespace cattle-system --set hostname=rancher.localhost --wait

hostsファイル登録
sudo vi /etc/hosts
127.0.0.1 myrancher.mydomain.com

Rancherへの接続
http://rancher.localhostを参照します












Rancher2 の構築からサービス公開まで
https://hawksnowlog.blogspot.com/2018/09/how-to-install-rancher2.html
https://blog.1q77.com/2019/03/rancher2-walk-through/

Rancherサーバーの起動
sudo docker run -d --restart=unless-stopped \
-p 20080:80 -p 20443:443 \
rancher/rancher:latest

# クラスタの追加
プロバイダー：カスタム
クラスタ名：rancher-cluster
ノードロール：etcd Control

sudo docker run -d --privileged --restart=unless-stopped --net=host -v /etc/kubernetes:/etc/kubernetes -v /var/run:/var/run rancher/rancher-agent:v2.3.5 --server https://localhost:20443 --token z92cpqlpg94k22glkvpjm9vmq62rbn2bbrzb7rt4q5nhqt2nnfrfcd --ca-checksum badbec56ebfe1af72c9a4f73f872fbebe5dfec41dd14bef514ca168a3951020c --etcd --controlplane

























Docker for Mac で Rancher を動かす
https://qiita.com/ntoreg/items/e1e63077ef0fef1f3ccc

Rancherサーバーの起動
sudo docker run -d -p 8080:8080 rancher/rancher

Host Registration URLを設定
http://localhost:8080 
「ADMIN」->「Settings」
※localhostや127.0.0.1ではなく、172.31.0.1を設定

Tips - 専用のIPを用意する
Network設定（メニューバーのWiFi -> Open Network Preferences..）を開きます。
左下の「＋」ボタンでネットワークを追加します。
Interfaceに「Wi-Fi」を選択して作成します。名前は任意で。
作成したネットワークを選択し「Advanced...」の設定項目に入ります。
TCP/IPタブで以下を設定
IPv4の設定・・・手動
IPv4アドレス・・・172.31.0.1
サブネットマスク・・・255.255.255.0

Rancherホストの追加
「INFRASTRUCTURE」->「Hosts」->「Add Host」画面で、Rancherエージェントのコンテナ作成用のコマンドをコピー

# ※コピーしたコマンドの中の、
#  "-v /var/lib/rancher:/var/lib/rancher"を"$HOME/rancher:/var/lib/rancher"へ変更
sudo docker run --rm --privileged \
-v /var/run/docker.sock:/var/run/docker.sock \
-v $HOME/rancher:/var/lib/rancher \
rancher/agent:v1.2.11 \
http://172.31.0.1:8080/v1/scripts/90F2E5BDCC5667784DCF:1577750400000:wNeBaXo8v9Qkvrsb1s1hfian2v0

Stackの作成
lib-test

webappサービスを作成
Name: webapp
Select Image: php:7.0-apache
Volumes: /Users/tadanobu/rancher/webapp/index.php:/var/www/html/index.php:ro # 作ったindex.phpをマウント。

rancher-lbサービスの作成
「STACKS→User→lib-test→Add Load Balancer」を選択して作成
Name: rancher-lb
Access: public
Protocol: HTTP
Port: 81 # rancher-lbのリッスンポート
Target: lib-test/webapp # 先ほど作ったwebappサービスを選択
Port: 80 # コンテナのポート

LBサービスの作成

Name: lb
Select Image: haproxy:latest
Port Map - Public Host Port: 10080
Port Map - Private Container Port: 80
Port Map - Protocol: TCP
Volumes: /Users/tadanobu/rancher/lb/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
Networking - Network: Bridge






rancher-lbサービスの作成
「STACKS→User→lib-test→Add Load Balancer」を選択して作成
Name: gitlab-server-lb
Access: public
Protocol: HTTP
Port: 181 # gitlab-server-lb-svのリッスンポート
Target: lib-test/webapp # 先ほど作ったwebappサービスを選択
Port: 80 # コンテナのポート

LBサービスの作成

Name: lb
Select Image: haproxy:latest
Port Map - Public Host Port: 10180
Port Map - Private Container Port: 80
Port Map - Protocol: TCP
Volumes: /Users/tadanobu/rancher/gitlab-server-lb-sv/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
Networking - Network: Bridge



# dockerコンテナ一括削除
docker rm -f `docker ps -a -q`

# dockerイメージ一括削除
docker rmi `docker images -q`
docker stop $(docker ps -q) && docker rmi $(docker images -q) -f

