1）删除远端最近的push

git push origin +HEAD^:dev-rh862

2)把最新 commit push到远端

git push origin dev-rh862

git push origin feature/dev-rhel81:dev82<----    feature/dev-rhel81是local branch name dev82是远端branch name，如果远端没有会创建一个

3)更改upstream

git remote set-url origin ssh://git@git.sankuai.com/INF/kernel.git

git remote set-url origin ssh://git@git.sankuai.com/~shuming02/kernel.git

增加一个新的remote

git remote add shuming ssh://git@git.sankuai.com/~shuming02/kernel.git

3) 列tag 和打tag时间

git log --tags --simplify-by-decoration --pretty="format:%ci %d"

4)当前headers

git show-ref

代码块
[shuming02@host kernel-rhel8]$ git branch
* dev-rhel81
  dev-rhel81-rto
  master
  mt20191225-323
[shuming02@xr-hulk-k8s-node1933 kernel-rhel8]$
[shuming02@xr-hulk-k8s-node1933 kernel-rhel8]$ git show-ref
451b2ba1b038d68d0aaa1319ec87acaf3656e426 refs/heads/dev-rhel81 <--- dev-rhel81
7b919d52383ac866b95ab19047c1890652444a0b refs/heads/dev-rhel81-rto <--- dev-rhel81-rto
d0d98c01f8f96e6514db1b76f132f7ad349a4c89 refs/heads/master <--- master 
9e900e9116edb35210c061a1d1dc432dae72e66f refs/tags/v4.18-mt20200626.413.kpatch2
bcc3e44c90d7d98479ddb24cd5d326e0ba723825 refs/tags/v4.18-mt20200626.413.kpatch3
如何从branch上发PR

代码块
git pull ssh://git@git.sankuai.com/~shuming02/osclinic release/testbranch
git rebase origin/release/testbranch release/testbranch
git push

