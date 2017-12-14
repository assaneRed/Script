To download the terrain and NLCD data tiles that are used for testing the reference implementation of the WInnForum propagation model:

1) Edit localconfig.py, and specify the local directories where the terrain and NLCD data should be downloaded.

2) Run ftp_3DEP_ref.py to download the terrain files. This will take a very long time to complete (several hours).

3) Run ftp_NLCD.py to download the NLCD tiles. This will not take quite so long.

Note that the following python modules must be installed:
- ftplib
- os
- zipfile

Questions? aclegg@google.com

