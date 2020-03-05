## Candidate Lab
This cloud-config.yaml will build a machine that has some issues baked in.  Each candidate will have three days to complete the lab before the machine automatically shuts off.  Each candidate gets an individual machine.

## Listing SSH Keys In Digital Ocean
Useful for updating the *--ssh-keys* parameter when creating droplets.

      doctl compute ssh-key list | cut -f 1 -d " "

or, if you forget that doctl is a thing :)

      curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" "https://api.digitalocean.com/v2/account/keys"|jq '.[][] | {id: .id}' -cr|grep -v null|cut -d ":" -f 2|sed "s/\}/,/"

Or, if you have `make`, just run `make list-keys`.

## Adding all keys from a given authorized keys file into DO
Useful for updating the *--ssh-keys* parameter when creating droplets.

      cut -d " " -f 2-3 /home/someuser/.ssh/authorized_keys | while read key name; do if [[ "$name" == "$oldname" ]]; then oldname=${name}2; else oldname=$name; fi; echo Name: $oldname Key: $key; curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -d "{\"name\":\"$oldname\",\"public_key\":\"ssh-rsa $key $oldname\"}" "https://api.digitalocean.com/v2/account/keys"; done

## Creating a Candidate Lab Machine
If you're not using make, first modify `cloud-config.yaml` and replace `SLACK_WEBHOOK` with your own webhook address and `SLACK_CHANNEL` with the desired Slack channel.

Also, you'll want to update the proctor SSH public key

To create a lab machine for a candidate, we'll use Digital Ocean and assume that you've already run `doctl auth init` to connect.  Set some environment variables with your values.

    export MACHINE_NICKNAME=JaneDoe        # used as the suffix for the droplet name, as well as the hostname
    export SLACK_CHANNEL=TheDesiredChannel
    export SLACK_WEBHOOK=https://hooks.slack.com/services/yyyyyyyy/zzzzzzz/xxxxxxxxxxxxxxxxxxx
    export SSH_KEY_IDS=xxxxxxxxx,yyyyyyyy  # found with "doctl compute ssh-key list" or created at https://cloud.digitalocean.com/account/security
    export PROCTOR_SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQClizdLNVOd6VpPgn+Olry1vaM2J1nkVilfzYMG7negQqm9QR4bPuvEV2Rg64396HhIpQVj7mERaQq6twoDYFFCJm2qAJFqvztjethuBmDe4FyN3tForqxqwKX+liH9obgBamMMUR1P+S0DmX9gqQ51efpcfvB9vu9sa1Ijc63V3TYizi1Wiz1LhxFAUvxz8Qgx1lUSKafQWHtgopfy370de8NZm2e12qQc009gfEB8OwsHP6Rbanp/BnpWVZb6QchR9wa9E7l7Y9bnZkrTG32HGgdfwRDCuvAujVk7InHCGFuQNegypnbypyhkadXhJWlWOVB06Lcdz6Wm5wHCKIPD proctor"

Then, if you don't have the `make` command:

    # modify the next line after creating an SSH key for the candidate to use
    export CANDIDATE_SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQClizdLNVOd6VpPgn+Olry1vaM2J1nkVilfzYMG7negQqm9QR4bPuvEV2Rg64396HhIpQVj7mERaQq6twoDYFFCJm2qAJFqvztjethuBmDe4FyN3tForqxqwKX+liH9obgBamMMUR1P+S0DmX9gqQ51efpcfvB9vu9sa1Ijc63V3TYizi1Wiz1LhxFAUvxz8Qgx1lUSKafQWHtgopfy370de8NZm2e12qQc009gfEB8OwsHP6Rbanp/BnpWVZb6QchR9wa9E7l7Y9bnZkrTG32HGgdfwRDCuvAujVk7InHCGFuQNegypnbypyhkadXhJWlWOVB06Lcdz6Wm5wHCKIPD candidate"
    
    export SLACK_WEBHOOK_ESCAPED=$(echo $SLACK_WEBHOOK | sed 's/\//\\\//g')
    export CANDIDATE_SSH_PUBLIC_KEY_ESCAPED=$(echo $CANDIDATE_SSH_PUBLIC_KEY | sed 's/\//\\\//g')
    export PROCTOR_SSH_PUBLIC_KEY_ESCAPED=$(echo $PROCTOR_SSH_PUBLIC_KEY | sed 's/\//\\\//g')
    sed "s/SLACK_CHANNEL/$SLACK_CHANNEL/g; s/SLACK_WEBHOOK/$SLACK_WEBHOOK_ESCAPED/g; s/PROCTOR_SSH_PUBLIC_KEY/$PROCTOR_SSH_PUBLIC_KEY_ESCAPED/g; s/CANDIDATE_SSH_PUBLIC_KEY/$CANDIDATE_SSH_PUBLIC_KEY_ESCAPED/g;" cloud-config.yaml > /tmp/cloud-config.yaml
    doctl compute droplet create candidate-lab-$MACHINE_NICKNAME --user-data-file /tmp/cloud-config.yaml --image ubuntu-18-04-x64 --region nyc3 --size s-1vcpu-1gb --tag-names tmp,lab --ssh-keys $SSH_KEY_IDS --wait

If you have `make` installed, simply run:

    make

### Granting More Time For the Lab
Cancel the pending shutdown and create a new one with `+2000` being the number of minutes that you would like to wait before shutdown.

      shutdown -c
      shutdown -h +2000 this lab machine will turn itself off

## Reviewing Lab Submissions
When the candidate completes the lab, we should be notified in slack.  We can log in as the candidate user using the proctor key or as root using the systems or our personal keys.

### Droplet Commands
* list droplets

      doctl compute droplet list

      # or

      make list-droplets

* power on a droplet by ID

      doctl compute droplet-action poweron 85337517

      # or

      DROPLET_ID=xxxxx make droplet-power-on

* delete a droplet

      doctl compute droplet delete candidate-lab-brian

      # or

      DROPLET_ID=xxxxx make droplet-delete

### Reviewing Process
1. turn on the droplet, if it's off
1. log in as root@$IP using the "systems" key, though the DevOps admins can just use their personal keys, which are set as the droplet is created
1. if you had to power on the droplet, run `mountlab` to reconfigure and mount the expected root devices.  If this fails, the candidate likely didn't follow the instructions.
1. run `lab` to see the numbered instructions
1. run `checklabwork` to automatically report on any missteps made by the candidate
1. if there were missteps, you may want to consider partial credit by
  1. browsing .bash_history of `root` and `candidate` users
  1. curl localhost and/or view /var/www/html/*, looking at PHP file(s) and for a .git directory
  1. df -P /var/log/apache2
  1. ls /home/proctor oro grep proctor /etc/passwd
  1. cat /var/log/apt/*
  1. mount|grep ext
## Assignment and Questions
See the cloud-config file.  The questions go into the message of the day file.

## Candidate Connection Information
Each candidate will need the connection details to accomplish the lab.  You might convey the details by email.  We create a candidate SSH key expressly for the purpose of the lab and host the lab on a Digital Ocean account that is only used for these lab machines.  So, we don't worry about the key being transmitted by email.  The `Makefile` generates and displays the connection details for pasting into an email to the candidate.  Or, if you don't use `make`, you should generate an SSH key (i.e. with ssh-keygen) and relay details *like* these to the candidate:

* Host: see the IP in the main body of the email
* Port: 22
* Username: candidate
* SSH Passphrase: UberSekret33
* SSH Public Key:

      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQClizdLNVOd6VpPgn+Olry1vaM2J1nkVilfzYMG7negQqm9QR4bPuvEV2Rg64396HhIpQVj7mERaQq6twoDYFFCJm2qAJFqvztjethuBmDe4FyN3tForqxqwKX+liH9obgBamMMUR1P+S0DmX9gqQ51efpcfvB9vu9sa1Ijc63V3TYizi1Wiz1LhxFAUvxz8Qgx1lUSKafQWHtgopfy370de8NZm2e12qQc009gfEB8OwsHP6Rbanp/BnpWVZb6QchR9wa9E7l7Y9bnZkrTG32HGgdfwRDCuvAujVk7InHCGFuQNegypnbypyhkadXhJWlWOVB06Lcdz6Wm5wHCKIPD candidate

* SSH Private Key:

      -----BEGIN OPENSSH PRIVATE KEY-----
      b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABCzToQ0pj
      tlWiC78fFoWGymAAAAEAAAAAEAAAEXAAAAB3NzaC1yc2EAAAADAQABAAABAQClizdLNVOd
      6VpPgn+Olry1vaM2J1nkVilfzYMG7negQqm9QR4bPuvEV2Rg64396HhIpQVj7mERaQq6tw
      oDYFFCJm2qAJFqvztjethuBmDe4FyN3tForqxqwKX+liH9obgBamMMUR1P+S0DmX9gqQ51
      efpcfvB9vu9sa1Ijc63V3TYizi1Wiz1LhxFAUvxz8Qgx1lUSKafQWHtgopfy370de8NZm2
      e12qQc009gfEB8OwsHP6Rbanp/BnpWVZb6QchR9wa9E7l7Y9bnZkrTG32HGgdfwRDCuvAu
      jVk7InHCGFuQNegypnbypyhkadXhJWlWOVB06Lcdz6Wm5wHCKIPDAAAD4PmWD9lxo94hIl
      hCGpX/5JGjAkeENDxIzWC3WavHsKvGvaM6yYRLVTrSwoD4/Y/+oATCCXTIRotw3p2Dxic7
      n0eVVpslfN6pRXAyH0CnaWpcaDQeJJNzUbscxdbtE76PIUWaxBxSHSm82/nrGn/gXXdGxQ
      Ji0kUFbDxab+5+ct9RembyiUTFxCe0f93jIMhLBpXxl04WLo3pVnP5Yxu7G20Y7x3ZVZZq
      3fYcI+zaRn9CnELhXr+flSt0xfR9QDnrhGzkkFYBwuN1jaj2nwKgep6MaiNUjgx5ltnMvj
      g5pkk72Txu+ETkOPoQN0+k+PeUQW4sVe0FtGSm+xNOLgGJt73E87zvt0xRt4BT2+TTvdNj
      w1yrDsnNedptXKq3pglhLZ8E+5CuGvQ1fIvvkPeaTodeXuSFVccDVr/9sIvCVJxQAWuteI
      wbjenybI1gq53pb3ywfkx2yID83TTFeKXHjuGuQgOgGwL/eEd229btSrWHuYaxEAqYT5H5
      MB/pEWUibqRavf6Hw2++8wk0elvZBjjW87Ty3xhL9iCrwHQFWhenoaNDxxWo/KvyESNOcG
      QwxAAi6+8yU6r1auEqBPmOiqGxhdvpWs4g7Xr9mPFTLS8tW80DcVY65G/tPaXMkg/BtL1I
      Nup6kqE25kEJTG674yyITzJU4I07xsqU9w9mSejve/3BzyiI0JqVW8hxjCfMRo+m5te7NJ
      NkeYsxMkXcq/u/WCxIQUjAgDD8ZQVZeCtL0TWnRwr4zCz1yvTPc0SG87m/nW7WKRMi/pqO
      LQX4rTq22dw2AQnkossQLJsQLGEVuVnLL9ky5diDrliStmvjQx0NFxYKKdgtNcdF2JZ7Sq
      lczlWCnW3odlnOfPP5rtJTFEKj1EyOXqBBnNJgnZ/rTCz3+1Uo+FhwLK+E9pTCAJeEpoAB
      gl5Kx/qhZ7H+9VF/ouoFAE5IgQgxy/WkvLUvsWC0bR1MA+xS4uIWwoh4VKs5w95Zbbz2w3
      YkyUsflryk/zEVObVusYCUoCm/QtTXP60lUpOSVWEnFhkm20malABBr2XlnWvjVh37JQnJ
      33WzpaVWWm3ma9s1Umy4+0lMpCOKW4vsRlmPRxvmJOVZtAoV52/1h+gblmucwX8GDFS2w4
      NJHti7Xs8VnAGyY0yWG+erHTrNDJCluPTWIyYCqSJrTTK1qad74kirskNDXm8s9T/NyUPK
      ZjTsa1q70qJ5K0oTjZhhmNLXG5+NfGEdslMhoz4AlRtt6b3ZOmwrEhuMK91pqY5tswbIfH
      kzgPUX95lpwZiwGDN541MfhJzrjOqjX/Bqfz5DjShJO4zGCeki
      -----END OPENSSH PRIVATE KEY-----
