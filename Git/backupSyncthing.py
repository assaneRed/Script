import os
import zipfile
import time

sources= ['/home/git/repositories','/home/red/Scripts/db','/opt/redmine/redmine-3.2.1/files/','/home/red/Subversion/repositories/red1']
now = time.strftime("%d_%m_%Y")
target= '/home/red/Sync/Syncthing/sync-' + now + '.zip'
folder='/home/red/Sync/Syncthing'
old = '/home/red/Sync/old/'

#Touch '/home/red/Sync/Syncthing/.stfolder' for it not to be moved to
#the '/home/red/Sync/old' directory
with open('/home/red/Sync/Syncthing/.stfolder', 'a'):
    os.utime('/home/red/Sync/Syncthing/.stfolder', None)
#Take a path as parameter recursively zips from path
def zipdir(path, ziph):
    # ziph is zipfile handle
    for root, dirs, files in os.walk(path):
        for file in files:
            ziph.write(os.path.join(root, file))

def addFileToZip(source):
    zipdir(source, zipf)

nowTime = time.time()
for x in os.listdir(folder):
    f = os.path.join(folder, x)
    if os.stat(f).st_mtime < nowTime - 5 * 86400:
        if os.path.isfile(f):
            os.remove(f))

zipf = zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, allowZip64=True)
#for i in sources:
addFileToZip('/home/red/Subversion/repositories/red1')
zipf.close()


