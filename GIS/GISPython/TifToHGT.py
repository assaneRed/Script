'''
Created on Nov 3, 2016

@author: Administrator
'''
import arcpy
import struct
from arcpy import env 

env.workspace = r"J:\GISData\bati\tifToBeConverted"  
targetWorkspace=r"J:\GISData\bati\tifToBeConverted\HGT\\"
#targetWorkspace=r"E:\hgt\\"
for file in arcpy.ListFiles("N48E001.tif"):
    
    out_raster = arcpy.Raster(file);
    array = arcpy.RasterToNumPyArray(out_raster)
    (height, width)=array.shape
    hgtFileName=file.replace(".tif", "BuildingHeights.hgt")
    print "generating "+targetWorkspace+hgtFileName
    test_file=open(targetWorkspace+hgtFileName,'wb+')
    countVide=0;  
    for row in range(0,height):
        for col in range(0,width):
            #two_byte = array.item(row,col).to_bytes(2, byteorder='big', signed=True) 
            val=struct.pack('h',array.item(row,col))
            test_file.write(val)
            #test_file.write(str((array.item(row,col))))
            #print val
            #if(array.item(row,col)==32000):
            #    countVide=countVide+1
    #print countVide
    test_file.close()
