'''
Created on Nov 3, 2016

@author: Administrator
'''
import arcpy
import struct
from arcpy import env 

env.workspace = r"D:\DELME\ORTHOMARSEILLE"  
targetWorkspace=r"D:\DELME\ORTHOMARSEILLE\Resampled\\"
#targetWorkspace=r"E:\hgt\\"
for file in arcpy.ListFiles("*.ecw"):
    
    out_raster = arcpy.Raster(file);
    array = arcpy.RasterToNumPyArray(out_raster)
    (height, width)=array.shape
    hgtFileName=file.replace(".ecw", ".tif")
    #hgtFileName=hgtFileName.replace("_", "")
    print "generating "+targetWorkspace+hgtFileName
    test_file=open(targetWorkspace+hgtFileName,'wb+')
    countVide=0;  
    
    test_file.close()
