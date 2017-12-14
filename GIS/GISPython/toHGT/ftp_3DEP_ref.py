# Script to download (via FTP) 3DEP data files that are used to compare
# reference implementations of the WinnForum propagation model.
#
# ***Do not use this script to download terrain data for production SAS use.
# The data downloaded by this script are a snapshot of terrain data, and are
# not updated.
#
# Andrew Clegg
# July 2017

from ftplib import FTP
import os
import zipfile

from localconfig import *

# Format the TERRAIN_DIR string correctly if needed
if TERRAIN_DIR[-1:] <> '/' and TERRAIN_DIR[-2:] <> '\\':
    TERRAIN_DIR += '/'

# If the terrain directory doesn't exist, create it
if not os.path.isdir(TERRAIN_DIR):
    os.makedirs(TERRAIN_DIR)

os.chdir(TERRAIN_DIR)

# Parameters needed to access the terrain data FTP site.
FTP_ADDRESS = 'ftp.w4je.com'
FTP_USER    = 'winnforum'
FTP_PWD     = '3.5GHz!'
FTP_DIR     = 'terrain'


# Open the FTP connection and cd to the appropriate data directory
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
            outfile = TERRAIN_DIR + f
            ftp.retrbinary("RETR " + f, open(outfile,'wb').write)
            zf = zipfile.ZipFile(outfile)
            for name in zf.namelist():
                print '  Extracting and decompressing ', name
                zf.extract(name, TERRAIN_DIR)
            zf.close()
            print '  Deleting zip file ', f
            os.remove(outfile)
