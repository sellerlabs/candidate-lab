.EXPORT_ALL_VARIABLES :
SLACK_WEBHOOK_ESCAPED = $(shell echo $(SLACK_WEBHOOK) | sed 's/\//\\\//g')
PROCTOR_SSH_PUBLIC_KEY_ESCAPED = $(shell echo $(PROCTOR_SSH_PUBLIC_KEY) | sed 's/\//\\\//g')
CANDIDATE_SSH_PUBLIC_KEY_ESCAPED =

all : ssh-key droplet-create display-connection-details

default : all

list-keys:
	doctl compute ssh-key list

configure-do-ctl:
	doctl auth init     # see lastpass for the API token; do this one time to set up doctl on your computer

droplet-create:
	@echo Checking for environment vars
	@test -n "$(MACHINE_NICKNAME)" || { echo set MACHINE_NICKNAME to distinguish this lab machine; exit 2; }
	@test -n "$(SSH_KEY_IDS)" || { echo You must set SSH_KEY_IDS, which IDs can be created at https://cloud.digitalocean.com/account/security; echo Current keys:; make list-keys; exit 1; }
	@test -n "$(SLACK_WEBHOOK)" || { echo set SLACK_WEBHOOK to allow notification of lab completion; exit 3; }
	@test -n "$(SLACK_CHANNEL)" || { echo set SLACK_CHANNEL to allow notification of lab completion; exit 4; }
	CANDIDATE_SSH_PUBLIC_KEY_ESCAPED = $(shell cat connection-details/$(MACHINE_NICKNAME).candidate_rsa.pub | sed 's/\//\\\//g'); \
	sed "s/SLACK_CHANNEL/$(SLACK_CHANNEL)/g; s/SLACK_WEBHOOK/$(SLACK_WEBHOOK_ESCAPED)/g; s/CANDIDATE_SSH_PUBLIC_KEY/$(CANDIDATE_SSH_PUBLIC_KEY_ESCAPED)/g; s/PROCTOR_SSH_PUBLIC_KEY/$(PROCTOR_SSH_PUBLIC_KEY_ESCAPED)/g; " cloud-config.yaml > /tmp/cloud-config.yaml
	# create lab machine
	doctl compute droplet create candidate-lab-$(MACHINE_NICKNAME) --user-data-file /tmp/cloud-config.yaml --image ubuntu-18-04-x64 --region nyc3 --size s-1vcpu-1gb --tag-names tmp,lab --ssh-keys $(SSH_KEY_IDS) --wait
	make list-droplets | grep candidate-lab-$(MACHINE_NICKNAME) | awk '{print $$3}' > connection-details/$(MACHINE_NICKNAME).address.txt

list-droplets:
	doctl compute droplet list

droplet-power-on:
	test -n "$(DROPLET_ID)" || { echo set a DROPLET_ID; make list-droplets; exit 3; }
	doctl compute droplet-action poweron $(DROPLET_ID)

droplet-delete:
	test -n "$(DROPLET_ID)" || { echo set a DROPLET_ID; make list-droplets; exit 3; }
	doctl compute droplet delete $(DROPLET_ID)

ssh-key:
	@test -d "connection-details" || mkdir connection-details
	@echo creating an SSH key for the candidate
	@ssh-keygen -b 2048 -t rsa -C "SSH key for the candidate" -N SuperDuperS3kret -f connection-details/$(MACHINE_NICKNAME).candidate_rsa

display-connection-details:
	@echo Relay these connection details to the candidate:
	@echo connection protocol - SSH
	@echo host - $(shell cat connection-details/$(MACHINE_NICKNAME).address.txt)
	@echo username - candidate
	@echo port - 22
	@echo SSH Key Passphrase - SuperDuperS3kret
	@echo SSH Public Key
	@cat connection-details/$(MACHINE_NICKNAME).candidate_rsa.pub
	@echo
	@echo SSH Private Key
	@cat connection-details/$(MACHINE_NICKNAME).candidate_rsa

clean:
	@echo removing address files and SSH keys created for candidates
	rm -rf connection-details
