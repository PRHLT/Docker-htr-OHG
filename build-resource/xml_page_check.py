import sys
import os
import xml.etree.ElementTree as ET

def touch(fname, times=None):
	with open(fname, 'a'):
		os.utime(fname, times)

dir_name = sys.argv[1]  

for file in os.listdir(dir_name):

	if file[-4:] == '.xml':
	
		xml_name = file 
	
		root = ET.parse(dir_name + xml_name).getroot()
		
		#print(root.tag.split('}')[-1])
		
		#print('\t', root[1].tag.split('}')[-1])
		
		counter = 0 
		
		for child in root[1]:
			#print('\t\t', child.tag.split('}')[-1])
			for child2 in child:
				#print('\t\t\t', child2.tag.split('}')[-1])
				if child2.tag.split('}')[-1] == 'TextLine':
					counter += 1
					found_bl = False
					for child3 in child2:
						#print('\t\t\t\t', child3.tag.split('}')[-1])
						if child3.tag.split('}')[-1] == 'Coords':
							if len(child3.attrib['points'].split()) < 4:
								touch('xml_errors')
								print(dir_name + xml_name)
								print('Less than 4 points TextLine in TextLine number ' + str(counter) + ' [ERROR]')
						if child3.tag.split('}')[-1] == 'Baseline':
							if len(child3.attrib['points'].split()) < 2:
								touch('xml_errors')
								print(dir_name + xml_name)	
								print('Less than 2 points Baseline in TextLine number ' + str(counter) + ' Baseline [ERROR]')
							else:
								bl_coords = [ (int(x.split(',')[0]),int(x.split(',')[1])) for x in child3.attrib['points'].split() ]
								#print('\t\t\t\t\t', bl_coords)
								bl_coordsx = sorted(bl_coords)
								bl_coordsy = sorted(bl_coords, key = lambda x : x[1])
								if (bl_coordsx[-1][0] - bl_coordsx[0][0]) < 25 and (bl_coordsy[-1][1] - bl_coordsy[0][1]) < 25:
									touch('xml_errors')
									print(dir_name + xml_name)
									print('Baseline of innapropiate size in TextLine number ' + str(counter) + ' Baseline [ERROR]')
							found_bl = True
					if not found_bl:
						touch('xml_errors')
						print(dir_name + xml_name)
						print('Missing Baseline [ERROR]')
