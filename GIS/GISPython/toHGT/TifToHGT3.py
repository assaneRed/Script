'''
Created on Nov 3, 2016

@author: Administrator
'''
import arcpy
import struct
from arcpy import env 

env.workspace = r"F:\GISData\ClutterExportForG"  
targetWorkspace=r"F:\GISData\ClutterExportForG\HGT\\"
#targetWorkspace=r"E:\hgt\\"
for file in arcpy.ListFiles("*.tif"):
    
    out_raster = arcpy.Raster(file);
    array = arcpy.RasterToNumPyArray(out_raster)
    (height, width)=array.shape
    hgtFileName=file.replace(".tif", ".HGT")
    #hgtFileName=hgtFileName.replace("_", "")
    print "generating "+targetWorkspace+hgtFileName
    test_file=open(targetWorkspace+hgtFileName,'wb+')
    countVide=0;  
    for row in range(0,height):
        for col in range(0,width):
            #two_byte = array.item(row,col).to_bytes(2, byteorder='big', signed=True) 
            val=struct.pack('B',array.item(row,col))
            test_file.write(val)
            #test_file.write(str((array.item(row,col))))
            #print val
            #if(array.item(row,col)==32000):
            #    countVide=countVide+1
    #print countVide
    test_file.close()
