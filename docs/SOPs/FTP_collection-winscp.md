# File access instructions (via FTP server)

## 1. Download WinSCP Client software
```
https://winscp.net/eng/download.php
```
> If you are an NHM staff member/student, you can find WinSCP via the Company Portal, if it is not already downloaded on your museum computer.


## 2. Set up NHM FTP server on WinSCP
In WinSCP, click on `New Site`:
  1. File Protocol: FTP (File Transfer Protocol)
  2. Host name: ftp-1.nhm.ac.uk
  3. Port number: 21
  3. Encryption: TLS/SSL Explicit encryption
  5. Username: mbl
  6. Click Save

<img width="397" height="412" alt="Screenshot 2026-06-25 110912" src="https://github.com/user-attachments/assets/a0167404-72a8-45a0-9107-431260b986f5" />


## 4. Enter password when prompted
> Note: This will be sent to you in an email when you have been notified that your data is available for pick up.

<img width="403" height="302" alt="image" src="https://github.com/user-attachments/assets/a50d0451-5a96-4a21-8c19-846ee8a7d4dd" />


## 6. You should now be connected
You can either:
1. 'Drag and Drop' your data folders from the right-hand side window (the remote connection to FTP server) to the left-hand side window (your local computer).
2. Transfer your data to your desired location using a transfer protocol, such FTP(E(S)) (e.g. using the `lftp` command).

---

## Contact
If you have any trouble with these steps or locating your data once connected, please get in touch with us at DNASeqFac@nhm.ac.uk