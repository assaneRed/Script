# Sets various local parameters for the hybrid propagation model.

# All directories must be complete absolute references.

# ***TERRAIN DATA DIRECTORY
# Directory where 3DEP-1 terrain grid files are located (*.flt). If the terrain
# files have not yet been downloaded, set this to the directory where you
# want them to be saved, and run download_3DEP.py. Thereafter, this is
# where the prop code will look for the terrain files.
#TERRAIN_DIR = '/media/aclegg/My Book Duo/terrain/'
TERRAIN_DIR = 'D:/3depFromPython/'

# ***UPDATE TIME (HR) FOR CHECKING FOR NEW TERRAIN FILES ON THE USGS SERVER
UPDATE_TIME = 24

# ***NATIONAL LAND COVER DATA (NLCD) DIRECTORY
# Directory where NLCD data are located. If the NLCD data have not yet been
# downloaded and regridded, set this to the directory where you want them to
# be, then run download_NLCD.py. Thereafter, this is where the prop code will
# look for the NLCD data.
#NLCD_DIR = '/media/aclegg/My Book Duo/NLCD/'
NLCD_DIR = 'D:/NLCDFromPython/'

