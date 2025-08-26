# Objective :

Create a 9 VMs POC of :
* 3 postgres clustered VMs
* 3 maas VMs
* 3 compute VMs for maybe later testing if possible (not tested yet)


# How to deploy this poc :

You'll need [vagrant](https://developer.hashicorp.com/vagrant/docs/installation) and install hostname plugin `vagrant plugin install vagrant-hostmanager`

For linux :
`vagrant plugin install vagrant-libvirt`

TODO : validate config for Virtualbox for windows

How to use this repo :

1. deploy VMs using `vagrant up`
2. run the ansible playbook : `ansible-playbook -i ./hosts.yaml    --extra-vars="maas_postgres_version_number=16 maas_version=3.6 maas_postgres_password=example maas_installation_type=snap maas_url=http://maas1.lan:5050/MAAS maas_postgres_replication_password=replication maas_postgres_floating_ip=192.168.121.160 maas_postgres_floating_ip_prefix_len=24 " site.yaml -v`

## Troubleshooting :

For some reason default config may not be ok of the VMs.
Run the `teardown.yaml` first then retry `site.yaml` (with the same options)

If you got an error for the floating IP then you'll have to connect to maas1 and remove the IP :
```
$ vagrant ssh maas1
$ ip addr del ip/24 dev ens5
```
