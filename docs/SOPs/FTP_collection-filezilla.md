# File access instructions (via FTP server)

## 1. Download FileZilla Client software
```
https://filezilla-project.org/
```
> Make sure you have clicked the download link for the Client, not the Server.


## 2. Set up NHM FTP server on FileZilla
In FileZilla, go to File -> Site Manager -> New Site -> give it a name (e.g. mbl) and specify the details below in the "General" tab:
  1. Protocol: FTP - File Transfer Protocol
  2. Host: ftp-1.nhm.ac.uk
  3. Encryption: Require explicit FTP over TLS
  4. Logon Type: Ask for password
  5. User: mbl
  6. Click Connect

<img width="806" height="475" alt="image" src="https://github.com/user-attachments/assets/9add2c3b-b343-4bc0-8265-3592c6891ea8" />


## 4. Enter password when prompted
> Note: This will be sent to you in an email when you have been notified that your data is available for pick up.

<img width="265" height="228" alt="image" src="https://github.com/user-attachments/assets/45e31310-ee69-44d0-9e28-c4762b804377" />


## 5. Check and confirm conneciton certificate
Tick the boxes and hit OK:
<img width="481" height="486" alt="image" src="https://github.com/user-attachments/assets/a38283ac-3c97-41f3-bb86-d320ae7e9f50" />


## 6. You should now be connected

You can either:
1. 'Drag and Drop' your data folders from the right-hand side window (the remote connection to FTP server) to the left-hand side window (your local computer).
2. Transfer your data to your desired location using a transfer protocol, such FTP(E(S)) (e.g. using the `lftp` command).

---

## Contact

If you have any trouble with these steps or locating your data once connected, please get in touch with us at DNASeqFac@nhm.ac.uk