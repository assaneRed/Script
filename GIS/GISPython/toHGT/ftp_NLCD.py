# Script to download (via FTP) NLCD data files that are used to compare
# reference implementations of the WinnForum propagation model.
#
# Andrew Clegg
# July 2017

from ftplib import FTP
import os
import zipfile

from localconfig import *

# Format the NLCD_DIR string correctly if needed
if NLCD_DIR[-1:] <> '/' and NLCD_DIR[-2:] <> '\\':
    NLCD_DIR += '/'

# If the NLCD directory doesn't exist, create it
if not os.path.isdir(NLCD_DIR):
    os.makedirs(NLCD_DIR)

os.chdir(NLCD_DIR)

# Parameters needed to access the NLCD data FTP site.
FTP_ADDRESS = 'ftp.w4je.com'
FTP_USER    = 'winnforum'
FTP_PWD     = '3.5GHz!'
FTP_DIR     = 'nlcd'

# Open the FTP connection and cd to the FTP data directory
ftp = FTP(host=FTP_ADDRESS, user=FTP_USER, passwd=FTP_PWD)
ftp.cwd(FTP_DIR)

fileList = ftp.nlst()

ifile = 0
for f in fileList:
    if f[-3:].lower() == 'zip':
        ifile += 1
        if ifile>1150:
            print 'File # ', ifile, ' out of ', len(fileList)
            print '  Downloading ', f
            outfile = NLCD_DIR + f
            ftp.retrbinary("RETR " + f, open(outfile,'wb').write)
            zf = zipfile.ZipFile(outfile)
            for name in zf.namelist():
                print '  Extracting and decompressing ', name
                zf.extract(name, NLCD_DIR)
            zf.close()
            print '  Deleting zip file ', f
            os.remove(outfile)
