# Transferring Data to the Remote FTP Server from the NHM HPC 

> - Author: Dan Parsons & Divya Annathurai
> - Date: April 2026 
> - Version: 1.0

--- 

## Overview 

This SOP describes how to transfer data (e.g. FASTQ files) from the HPC to the remote FTP server using lftp. Plain FTP servers do not support SSH-based protocols such as rsync or scp, so lftp is used instead. lftp provides a reliable, command-line FTP client with support for recursive transfers, resumption of interrupted transfers, and secure password entry. 

---

## Prerequisites 

- Access to the HPC via SSH
- lftp installed (e.g. in conda env) and available on the cluster (verify with: which lftp) 
- FTP server credentials: 
  - Host: ftp-1.nhm.ac.uk 
  - Username: mbl 
  - Password: **PLEASE SEE SHAREPOINT SOP VERSION FOR PASSWORD **

---

## Steps 

### Step 1 — Connect to the HPC  
Log in to the HPC as normal via SSH: 
```
ssh [username]@hpc-jobs-001.nhm.ac.uk 
```

### Step 2 — Start a Screen Session (Recommended) 
`screen` keeps your terminal session alive on the server even if your SSH connection drops. This is important for large transfers that may run for minutes to hours. Without screen, a dropped connection will kill the transfer mid-way. 
```
Screen -S ftp_transfer 
```
> Note: To detach from screen without stopping the transfer, press Ctrl+A then D.  
> To reattach later, run: screen -r ftp_transfer 


### Step 3 — Launch lftp and Connect to the FTP Server 
Connect to the FTP server using the server hostname. This opens an lftp prompt — at this point you are connected to the server but not yet authenticated. 
```
lftp ftp://ftp-1.nhm.ac.uk 
```
 

### Step 4 — Log In with Your Credentials 
At the lftp prompt, authenticate with your username. You will be prompted for your password - it will not be echoed to the terminal or stored in shell history. 
```
lftp ftp-1.nhm.ac.uk:~> login mbl 
Password: **PLEASE SEE SHAREPOINT SOP VERSION FOR PASSWORD**
```

### Step 5 — Navigate to the Target Directory on the FTP Server 
Once logged in, change to the directory on the FTP server where files should be deposited. Use ls and pwd to confirm your location before transferring. 
```
# Print working directory
pwd
# Move into desired directory
cd /path/on/ftp/server/
# List everything inside that directory
ls 
```
 

### Step 6 — Transfer Files 
- **Option A** - Transfer a Single File 
Use `put` to upload a single file from the cluster to the current directory on the FTP server. Specify the full local path on the HPC. 
```
put /path/to/file.fastq.gz 
```
 
- **Option B** - Transfer a Whole Directory Recursively 
Use `mirror -R` to recursively upload an entire local directory to the FTP server. The `-R` flag reverses the default mirror direction (which is download) to perform an upload. lftp will replicate the full directory structure on the FTP server. 
```
mirror -R /path/to/local/dir/ /path/on/ftp/server/ 
```
> - Note: If the transfer is interrupted, simply re-run the same `mirror -R` command. lftp will automatically skip files already successfully transferred and resume from where it left off. 
> - Note: You can only send a single directory at a time using the `mirror` command. To transfer several directories, you will need to run the command multiple times. 


### Step 7 — Verify the Transfer 
After the transfer completes, confirm that the expected files are present on the FTP server and appear to be the correct size: 
```
ls -lh /path/on/ftp/server/ 
```


### Step 8 — Exit lftp 
When finished, close the lftp session cleanly: 
```
exit 
```
 

### Step 9 — Close the tmux Session 
If you opened a Screen session in Step 2, close it once the transfer is confirmed complete: 
```
exit 
```
 

## Troubleshooting 
| Issue | Likely cause | Resolution |
| --- | --- | --- |
| `lftp: command not found`  | lftp not in PATH | Run `which lftp` to check if `lftp` is installed in your conda env? 
| Login failed | Incorrect credentials | Double-check username and password |
| Transfer stalls or drops | Unstable network | Re-run `mirror -R` command - lftp will resume automatically | 
| Permission denied on FTP | Wrong target directory | Check with HPC system administrators that you have permission |


## Additional Notes 
> - Plain FTP transmits credentials and data unencrypted over the network. This is a limitation of the protocol and cannot be avoided if the server only supports FTP. Be aware of this on shared network infrastructure. 
> - Do not store FTP passwords in scripts, .bashrc, or any version-controlled files. 
> - For very large datasets, consider wrapping the lftp transfer in a SLURM job to avoid HPC login node resource limits. 