'''
Created on Nov 3, 2016

@author: Administrator
'''
import arcpy
import struct
from arcpy import env 

env.workspace = r"C:\DataFolder\Data\Terrain\SRTM1"  
targetWorkspace=r"F:\GISData\Altitudes\SRTMClippedMNT\HGT\\"
#targetWorkspace=r"E:\hgt\\"
for file in arcpy.ListFiles("*.hgt"):
    
    in_raster = arcpy.Raster("G:\\delme\\batiTry10.tif");
    print in_raster.meanCellHeight
    snapRaster = arcpy.Raster(file);
    array = arcpy.RasterToNumPyArray(snapRaster)
    inRasterToArray = arcpy.RasterToNumPyArray(in_raster)
    (height, width)=array.shape
    hgtFileName=file.replace(".tif", ".HGT")
    #hgtFileName=hgtFileName.replace("_", "")
    print "generating "+targetWorkspace+hgtFileName
    #test_file=open(targetWorkspace+hgtFileName,'wb+')
    countVide=0;  
    for row in range(0,height):
        for col in range(0,width):
            #two_byte = array.item(row,col).to_bytes(2, byteorder='big', signed=True) 
            
            outRasterPointX =  snapRaster.extent.XMin+ col*snapRaster.meanCellWidth
            outRasterPointY = snapRaster.extent.YMax - row*snapRaster.meanCellHeight
            
            xmin = outRasterPointX - snapRaster.meanCellWidth/2
            xmax = outRasterPointX + snapRaster.meanCellWidth/2
            ymin = outRasterPointY - snapRaster.meanCellHeight/2
            ymax = outRasterPointY + snapRaster.meanCellHeight/2
            x = xmin 
            
            while x<=xmax:
                y = ymax
                print "y " + str(outRasterPointY)
                while y>=ymin:
                    
                    xIndexIninputRaster = int((x - in_raster.extent.XMin)/in_raster.meanCellWidth)
                    yIndexIninputRaster = int((in_raster.extent.XYMax - y)/in_raster.meanCellHeight)
                    val = struct.pack('h',inRasterToArray.item(xIndexIninputRaster,yIndexIninputRaster))
                    y -= in_raster.meanCellHeight
            print "endx1"
            
             
           
            #test_file.write(val)
            #test_file.write(str((array.item(row,col))))
            #print val
            #if(array.item(row,col)==32000):
            #    countVide=countVide+1
    #print countVide
    #test_file.close()
