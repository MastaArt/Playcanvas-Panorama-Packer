/*  
[INFO] 
NAME = Playcanvas Panorama Packer
VERSION = 1.2.0
AUTHOR = MastaMan
DEV = https://3dground.net
HELP = 
[1.0.0]
* Initial release =

[1.0.1]
* Changed: Improved speed of clearing Smooth Groups =

[1.1.0]
+ Added: Resizing Cubemaps =

[1.2.0]
+ Added: Custom Export Cubemaps (Configurator) =

[SCRIPT]
*/


try(closeRolloutFloater fPlaycanvasPanoramaPacker) catch()
global fPlaycanvasPanoramaPacker = newRolloutFloater "Playcanvas Panorama Packer" 360 680


tool CoronaCamCreator (
	local c, createCam
	fn createCam = (
		pos = worldPoint
		in coordsys grid (
			c = CoronaCam pos: worldPoint targeted: false Projection: 4 name: (uniqueName "Cam_") wirecolor: yellow
			rotate c (EulerAngles 90 0 0)
			c.pos.z += (units.decodeValue "160cm")
		)		
	)

	on mousePoint click do (
		createCam()
		#stop
	)
)

tool VrayCamCreator (
	local c, createCam
	fn createCam = (
		pos = worldPoint
		in coordsys grid (
			c = VRayPhysicalCamera pos: worldPoint targeted: false name: (uniqueName "Cam_") wirecolor: yellow
			rotate c (EulerAngles 90 0 0)
			c.pos.z += (units.decodeValue "160cm")					
		)
		
		local r = renderers.current
		try (r.camera_type = 10) catch()
	)

	on mousePoint click do (
		createCam()
		#stop
	)
)

global _rStepPPP0
global _rStepPPPBatchRender
global GLOBAL_CUBEMAP_TYPES = #(#day, #night)

rollout _rStepPPP0  "Cubemap Packer" (
	group "Renderer Engine" (
		radiobuttons rdoRenderer labels: #("Corona", "V-Ray") align: #left
	)
	
	group "Cameras List" (
		multiListbox lbxCameras "" height: 15
		button btnCreateCamera "Create Camera" width: 150 across: 2 
		button btnUpdate "Update List" width: 150
	)
	
	group "Cubemap Binding" (
		button btnBindDay "Day Cubemaps" width: 150 across: 2 
		button btnBindNight "Night Cubemaps" width: 150
		
		button btnUnbindAll "Unbind All" width: 150 across: 2 
		button btnDummy "" width: 150 enabled: false
	)
	
	group "Export Cubemaps" (
		button btnExportCubemaps "Export Cubemaps"  width: 310
		checkbox cbxExportSelectedCubemaps "Export Only Selected" across: 2
		spinner spnCubemapsQuality "Quality: " range: [1, 100, 86] scale: 1 type: #integer fieldWidth: 30 align: #left
		spinner spnMinCubemapSize "Mobile Cube Size: "  range: [500, 6000, 1000] scale: 1 type: #integer fieldWidth: 40 align: #left across: 2
		spinner spnMaxCubemapSize "Desktop Cube Size: "  range: [500, 6000, 1500] scale: 1 type: #integer fieldWidth: 40 align: #left across: 2
	)
	
	group "Export Cameras (Hotspots)" (
		button btnExportCameras "Export Cameras"  width: 310
	)
	
	group "Export Architecture (Model)" (
		button btnExportModel "Export Model"  width: 310
	)
		
	fn boost = (
        if (((maxVersion())[1] / 1000) >= 13) do windows.processPostedMessages() 
    )
	
	fn getSaveDir type: "jpg" = (
        type = (toUpper type) +" (*." + type + ")|*." + type
        f = getSaveFileName filename: "DO NOT CHANGE NAME" caption:"Save File" types: type
        if(f == undefined) do return f
        
        p = getFileNamePath f
		
        return p
    )
	
	fn upperCase v = (
		local j = copy (v as string)
		j[1] = toUpper j[1]
		return j
	)
		
	fn isCorona = (
		local r = renderers.current		
		if (matchpattern (r as string) pattern:"*Corona*") do return true		    
        return false
	)
	
	fn isVray = (
		local r = renderers.current		
		if (matchpattern (r as string) pattern:"V_Ray_*") do return true		    
        return false
	)
	
	fn detectRenderByCameras = (
		local o = #()
		for c in cameras do appendIfUnique o ((classOf c) as string)
		
		for i in o where (MatchPattern i pattern: ("*VRay*")) do return 2
		for i in o where (MatchPattern i pattern: ("*Corona*")) do return 1
		return undefined
	)
	
	
	fn isCubeCam c = (
		local s = rdoRenderer.state
		case s of (
			2: return classOf c == VRayPhysicalCamera and c.targeted == false
			default: return classOf c == CoronaCam and c.Projection == 4 and c.targeted == false
		)
	)
	
	fn getProp o k = (
		local p = getUserProp o (k as string)		
		if (p == undefined) do p = ""
		return p
	)
	
	fn setProp o k v = (
		setUserProp o (k as string) (v as string)
	)

	fn getCameraList = (		
		local names = for i in cameras where (isCubeCam i) collect i.name
		sort names
		local cams = for n in names collect (getNodeByName n exact: true all: true ignoreCase: true)[1]
		
		local list = #()
		for c in cams do (			
			local day = getProp c "day"
			local night = getProp c "night"
			local dayName = getFilenameFile day
			local nightName = getFilenameFile night
			
			if (not doesFileExist day) do (
				day = ""
				dayName = ""
			)
			if (not doesFileExist night) do (
				night = ""
				nightName = ""
			)
			
			local l = c.name + " (D: " + dayName + "| N: " + nightName + ")"
			
			struct tmp (obj, name, day, night, dayName, nightName)	
			append list (tmp obj: c name: l day: day night: night dayName: dayName nightName: nightName)
		)
		
		return list
	)
	
	fn updateCameraList = (
		local list = getCameraList()
		
		lbxCameras.items = for c in list collect c.name
	)
	
	fn unbindAll = (
		local list = getCameraList()
		
		for i in list do (
			for t in ::GLOBAL_CUBEMAP_TYPES do setUserProp  i.obj t ""			
		)
		
		updateCameraList()
	)
	
	fn bindCubemaps type: #day = (
		local p = getSavePath()
		if (p == undefined) do return false
		
		local nums = "0123456789"
		local postfix = "#" + (type as string)
		
		local list = getCameraList()
		
		p += @"\"
		
		local files = getFiles (p + "*.jpg")		
		local foundNames = #()
		local foundPaths = #()
		
		for f in files do (
			local n = getFilenameFile f
			n = trimRight n nums
			n = trimRight n "_"
			if (findString n postfix == undefined) do continue
			n = substituteString n postfix ""
			
			append foundNames n
			append foundPaths f
		)
		
		
		for i in list do (
			local n = i.obj.name
			local id = findItem foundNames n
			if (id == 0) do continue
			local f = foundPaths[id]
			
			setProp i.obj type f
		)
		
		updateCameraList()		
	)
	
	fn resizeCubeMap f size: 1000 quality: 100 postfix: "_low" = (
		local p = getFileNamePath f
		local t = getFileNameType f
		local n = copy (getFilenameFile f)
		
		local size = size as string + "x" + size as string
		
		local selfPath = getFileNamePath (getThisScriptFileName())				
		local convertexe = selfPath + "convert.exe"
		local tmpDir = @"C:\temp\"
		local tmpConvertexe = tmpDir + "convert.exe"
		makeDir tmpDir
		copyFile convertexe tmpConvertexe
		
		local exe = tmpConvertexe
			
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = selfPath
		
		local nn = p + n + postfix + t
		
		local cmd = exe + " -quality " + (quality as string) + " -resize " + size + " \"" + f + "\" \"" + nn + "\""									
		hiddenDosCommand cmd exitcode:&exitcode	

		sysInfo.currentDir = curDir
			
		return nn	
	)
	
	fn optimizeImages files: #() quality: 100 = (
		if (files.count == 0) do return false
		
		local selfPath = getFileNamePath (getThisScriptFileName())
		local jpgoptim = "\"" + selfPath + "jpegoptim.exe\""
		local p = getFilenamePath files[1]
			
		curDir = sysInfo.currentDir
		sysInfo.currentDir = p
			
		local imgs = ""
		
		for i in files do imgs += "\"" + (filenameFromPath i) + "\" "
		
		local cmd = jpgoptim + " --strip-all --all-progressive -f -o -q -m" + (quality as string) + "  " + imgs
		
		hiddenDosCommand cmd exitcode:&exitcode	
		
		sysInfo.currentDir = curDir 
	)
	
	fn bitmapFlip f flip: #RotateNoneFlipX = (
		/*
		Rotate180FlipNone 	2	- Specifies a 180-degree clockwise rotation without flipping.
		Rotate180FlipX		6	- Specifies a 180-degree clockwise rotation followed by a horizontal flip.
		Rotate180FlipXY		0	- Specifies a 180-degree clockwise rotation followed by a horizontal and vertical flip.
		Rotate180FlipY		4	- Specifies a 180-degree clockwise rotation followed by a vertical flip.
		Rotate270FlipNone 	3 	- Specifies a 270-degree clockwise rotation without flipping.
		Rotate270FlipX		7	- Specifies a 270-degree clockwise rotation followed by a horizontal flip.
		Rotate270FlipXY		1	- Specifies a 270-degree clockwise rotation followed by a horizontal and vertical flip.
		Rotate270FlipY 		5	- Specifies a 270-degree clockwise rotation followed by a vertical flip.
		Rotate90FlipNone 	1 	- Specifies a 90-degree clockwise rotation without flipping.
		Rotate90FlipX 		5	- Specifies a 90-degree clockwise rotation followed by a horizontal flip.
		Rotate90FlipXY 		3	- Specifies a 90-degree clockwise rotation followed by a horizontal and vertical flip.
		Rotate90FlipY 		7	- Specifies a 90-degree clockwise rotation followed by a vertical flip.
		RotateNoneFlipNone	0 	- Specifies no clockwise rotation and no flipping.
		RotateNoneFlipX		4	- Specifies no clockwise rotation followed by a horizontal flip.
		RotateNoneFlipXY	2 	- Specifies no clockwise rotation followed by a horizontal and vertical flip.
		RotateNoneFlipY		6	- Specifies no clockwise rotation followed by a vertical flip.
		*/
		
		local fs = dotnetObject "System.IO.FileStream" f (dotnetClass "System.IO.FileMode").open
		local tempBmp = dotnetObject "System.Drawing.Bitmap" fs
		local b = tempBmp.Clone()
		tempBmp.Dispose()
		fs.Close()
		
		local t = dotNetClass "System.Drawing.RotateFlipType"
		b.RotateFlip (getProperty t flip)
		
		b.Save f
		b.Dispose()		
	)
	
	fn bitmapFlipAndRotate f u: -1 v: 1 rot: 0 = (
		local tx = BitmapTex filename: f
		tx.coords.U_Tiling = u
		tx.coords.V_Tiling = v
		tx.coords.W_angle = rot
		local w = tx.bitmap.width
		local h = tx.bitmap.height
		return renderMap tx filter: true size: [w, h] display: false
	)
	
	fn sliceCubeMap f dir fileName parts: 6 type: #day pcSize: 1500 mobileSize: 1000 = (
		gc()
		
		local cubeMap = #()
		local b = openBitmap f
		
		if (b == undefined) do return #()
		
		local w = b.width / parts
		local h = b.height
		
		local tmpName = copy fileName

		local suffixes = #(
			#("_f", -1, 1, 0),
			#("_b", -1, 1, 0),
			#("_u", -1, 1, -90),
			#("_d", -1, 1, 90),
			#("_r", -1, 1, 0), 
			#("_l", -1, 1, 0)
		)
		
		-- If VRay
		if (rdoRenderer.state == 2) do (
			suffixes = #(
				#("_r", -1, 1, 0),
				#("_l", -1, 1, 0),
				#("_u", -1, 1, -180),
				#("_d", -1, 1, 180),
				#("_b", -1, 1, 0),
				#("_f", -1, 1, 0)
			)
		)
		
		local postfix = ""
		if (type != undefined) do postfix = "_" + (type as string)
		
		for i in 1 to parts do (
			local tmp = copy (bitmap w h)
			local nn =  tmpName + suffixes[i][1] + postfix + ".jpg"
			local ff = dir + nn
			local tmp_ff = dir + "tmp_" + nn
			if (doesFileExist ff) do deleteFile ff
			
			local p = (i - 1) * w
			
			pasteBitmap b tmp (box2 p 0 w h) [0, 0]
			
			JPEG.setquality 100
			tmp.filename = ff
			
			save tmp
			close tmp
			
			gc()
			
			local u = suffixes[i][2]
			local v = suffixes[i][3]
			local r = suffixes[i][4]
			
			tmp2 = bitmapFlipAndRotate ff u: u v: v rot: r
			tmp2.filename = ff
			local ww = tmp2.width
			local hh = tmp2.height
			
			save tmp2
			close tmp2
			deleteFile tmp_ff
			
			-- Resize
			local mobileCube = resizeCubeMap ff size: mobileSize postfix: "_low"			
			local pcCube = resizeCubeMap ff size: pcSize postfix: ""
			
			append cubeMap mobileCube
			append cubeMap pcCube
			
			gc()			
		)
		
		close b
		gc()
		
		return cubeMap
	)
	
	fn exportCubemaps quality: 100 pcSize: 1500 mobileSize: 1000 = (
		local ss = lbxCameras.selection as array
		if (cbxExportSelectedCubemaps.checked and ss.count == 0) do return messageBox "Please select Cameras in list!" title: "Warining!"
		
		if(maxFileName == "") do return messageBox "Please save scene first!" title: "Warning!"	
		local p = getSaveDir()
		if (p == undefined) do return false
		makeDir p all: true
		max file save
		
		local list = getCameraList()
		
		progressStart "Export Cubemaps..."
		local isSelected = cbxExportSelectedCubemaps.checked
		
		for i in 1 to list.count do (		
			if (isSelected and (findItem ss i) == 0) do continue
			
			
			local h = list[i]
			local o = h.obj
			local n = o.name
			
			for t in ::GLOBAL_CUBEMAP_TYPES do (
				local f = getProp o t
				if (f == "" or not doesFileExist f) do continue
				local d = p + upperCase t + @"\"
				makeDir d all: true
				local cubeMap = sliceCubeMap f d n type: t pcSize: pcSize mobileSize: mobileSize
				optimizeImages files: cubeMap quality: quality
			)	
			
			progressUpdate ((i as float / list.count) * 100.0)
			boost()
		)
		
		progressEnd()
		
		local q = queryBox "Do you want to open containing folder?" title: "Success!"
		if(q) do shellLaunch p ""	
	)
	
	fn exportCameras = (
		local p = getSaveDir type: "fbx"
		if (p == undefined) do return false
		
		local n = "Hotspots"
		local list = getCameraList()
		local size = units.decodeValue "10cm"
		local boxes = #()
		
		for i in list do (
			local b = box width: size height: size length: size wirecolor: yellow name: i.obj.name pos: i.obj.pos
			append boxes b
		)
		
		clearSelection()
		select boxes
		
		FBXExporterSetParam "Animation" false
		FBXExporterSetParam "ShowWarnings" false
		FBXExporterSetParam "EmbedTextures" false
		FBXExporterSetParam "SmoothingGroups" false
		FBXExporterSetParam "Cameras" false
		
		local f = p + n + ".fbx"
		if (doesFileExist f) do deleteFile f
		
		exportFile f #noPrompt selectedOnly: true
		
		try (delete boxes) catch ()
		
		q = queryBox "Do you want to open containing folder?" title: "Success!"
		if(q) do shellLaunch p ""	
	)
	
	fn clearMapping o = (
		for nm in 1 to (meshop.getNumMaps o) do (
			if (meshop.getmapsupport o nm) do (
				try (
					meshop.freeMapChannel o nm		
					meshop.freeMapVerts o nm
					meshop.freeMapFaces o nm	
					meshop.setMapSupport o nm off
				) catch()
			)
		)
	)
	
	fn exportModel = (
		if (selection.count == 0) do return messageBox "Please select model!" title: "Error!"
		if (selection.count > 1) do return messageBox "Please select only one object!" title: "Error!"
		
		local model = selection[1]
		
		if (classOf model != Editable_Poly and classOf model != Editable_Mesh) do return messageBox "Please select proper object (Editable Poly/Mesh)!" title: "Error!"
		
		if(not canConvertTo model Editable_Mesh) do return messageBox "This object can't conver to Editable Mesh!" title: "Error!"
		
		local p = getSaveDir type: "fbx"
		if (p == undefined) do return false
		
		addModifier model (smooth())
		model.modifiers[#Smooth].autosmooth = false
		
		try(convertToMesh model) catch()
		clearMapping model
		
		--meshop.autosmooth model model.faces 0
		--update model
		
		local n = "Model"
			
		model.name = n	
		local f = p + n + ".fbx"
		if (doesFileExist f) do deleteFile f
		
		FBXExporterSetParam "Animation" false
		FBXExporterSetParam "ShowWarnings" false
		FBXExporterSetParam "EmbedTextures" false
		FBXExporterSetParam "SmoothingGroups" false
		FBXExporterSetParam "Cameras" false
		
		exportFile f #noPrompt selectedOnly: true
		
		q = queryBox "Do you want to open containing folder?" title: "Success!"
		if(q) do shellLaunch p ""	
	)
	
	on btnBindDay pressed do (
		bindCubemaps type: #day
	)
	
	on btnBindNight pressed do (
		bindCubemaps type: #night
	)
	
	on btnUnbindAll pressed do (
		local q = queryBox "Do you really want to unbind all Cubemaps?" title: "Confirm?"
		if (not q) do return false
		unbindAll()
	)
	
	on btnCreateCamera pressed do (
		case rdoRenderer.state of (
			2: startTool VrayCamCreator
			default: startTool CoronaCamCreator
		)
		updateCameraList()
	)
	
	on btnUpdate pressed do (
		updateCameraList()
	)
	
	on btnExportCubemaps pressed do (
		local pcSize = spnMaxCubemapSize.value
		local mobileSize = spnMinCubemapSize.value
		local q = spnCubemapsQuality.value
		exportCubemaps quality: q pcSize: pcSize mobileSize: mobileSize
	)
	
	on btnExportCameras pressed do (
		exportCameras()
	)
	
	on btnExportModel pressed do (
		exportModel()
	)
	
	on _rStepPPP0 open do (
		if (not isCorona() and not isVray()) do (
			messageBox "Your scene must be created in Corona or V-Ray Renderer!" title: "Error!"
			return try(closeRolloutFloater fPlaycanvasPanoramaPacker) catch()
		)
		
		local s = detectRenderByCameras()
		if (s != undefined) then (
			rdoRenderer.state = s
		) else (
			if (isVray()) do rdoRenderer.state = 2
		)
			
		updateCameraList()
	)
)

rollout _rStepPPPCustomExportCubemaps  "Custom Export Cubemaps (Configurator)" (
	group "Export Cubemaps" (
		button btnSelectCubemaps "Select Cubemaps"  width: 310 
		
		spinner spnCubemapsQuality "Quality: " range: [1, 100, 86] scale: 1 type: #integer fieldWidth: 30 align: #left offset: [0, 10]
		spinner spnMinCubemapSize "Mobile Cube Size: "  range: [500, 6000, 1000] scale: 1 type: #integer fieldWidth: 40 align: #left across: 2
		spinner spnMaxCubemapSize "Desktop Cube Size: "  range: [500, 6000, 1500] scale: 1 type: #integer fieldWidth: 40 align: #left across: 2
		
		button btnExportCubemaps "Export Cubemaps"  width: 310 offset: [0, 10]
	)
	
	global _CUSTOM_EXPORT_CUBEMAPS_FILES = #()
	
	fn getOpenImage = (
        local f = #()
        
        imageDialog = dotNetObject "System.Windows.Forms.OpenFileDialog" 
        imageDialog.title = "Select Pictures"
        imageDialog.Multiselect = true
        imageDialog.Filter = "Image files (*.jpg ) | *.jpg;"
        imageDialog.FilterIndex = 1
        
        local r = imageDialog.showDialog() 
        r.ToString()
        r.Equals r.OK
        r.Equals r.Cancel
        
        f = imageDialog.fileNames 
         
        return f
    )
	
	fn getSaveDir type: "jpg" = (
        type = (toUpper type) +" (*." + type + ")|*." + type
        f = getSaveFileName filename: "DO NOT CHANGE NAME" caption:"Open Files" types: type
        if(f == undefined) do return f
        
        p = getFileNamePath f
		
        return p
    )
	
	fn boost = (
        if (((maxVersion())[1] / 1000) >= 13) do windows.processPostedMessages() 
    )
	
	fn exportCubemaps quality: 100 pcSize: 1500 mobileSize: 1000 = (		
		if (::_CUSTOM_EXPORT_CUBEMAPS_FILES.count == 0) do return messageBox "Please Panos for export!" title: "Error!"
		
		local p = getSaveDir()
		if (p == undefined) do return false
		
		local list = ::_CUSTOM_EXPORT_CUBEMAPS_FILES
		
		progressStart "Export Cubemaps..."
		
		for i in 1 to list.count do (				
			local f = list[i]
			local n = getFilenameFile f
			
			local cubeMap = _rStepPPP0.sliceCubeMap f p n type: undefined pcSize: pcSize mobileSize: mobileSize
			_rStepPPP0.optimizeImages files: cubeMap quality: quality
			
			
			progressUpdate ((i as float / list.count) * 100.0)
			boost()
		)
		
		progressEnd()
		
		local q = queryBox "Do you want to open containing folder?" title: "Success!"
		if(q) do shellLaunch p ""	
	)
	
	on btnSelectCubemaps pressed do (
		::_CUSTOM_EXPORT_CUBEMAPS_FILES = #()
		
		local f = getOpenImage()
		if (f.count == 0) do return btnSelectCubemaps.caption = "Select Cubemaps"
		
		local t = ""
		for i in f do t += (getFilenameFile i) + ", "
		t = trimRight t ", "
		
		btnSelectCubemaps.caption = t
		
		::_CUSTOM_EXPORT_CUBEMAPS_FILES = f
	)
	
	on btnExportCubemaps pressed do (
		local pcSize = spnMaxCubemapSize.value
		local mobileSize = spnMinCubemapSize.value
		local q = spnCubemapsQuality.value
		exportCubemaps quality: q pcSize: pcSize mobileSize: mobileSize
	)
)

rollout _rStepPPPBatchRender  "Batch Render" (
	group "Cubemap Render Size" (
		spinner spnMinRenderHeight "Render Height: " range: [512, 4096, 2048] type: #integer scale: 256 fieldWidth: 70 align: #left
	)

	group "Out Folder" (	
		edittext edtOutBatchRenderPath "" readonly: true across: 2 align: #left fieldwidth: 270
        button btnOutBatchRenderPath "..." width: 35  align: #right offset: [0, -2]
	)
		
	group "Quick Setup" (
		button btnSetupBatchRenderDay "Setup Batch Render Day" width: 150 across: 2
		button btnSetupBatchRenderNight "Setup Batch Render Night" width: 150 across: 2
	)
	
	button btnStartBatchRender "Start Batch Render"  width: 310 height: 35 offset: [0, 10]
	
	fn getSaveDir type: "jpg" = (
        type = (toUpper type) +" (*." + type + ")|*." + type
        f = getSaveFileName filename: "DO NOT CHANGE NAME" caption:"Save File" types: type
        if(f == undefined) do return f
        
        p = getFileNamePath f
		
        return p
    )
	
	fn setupBatchRender type: #day = (
		local p = edtOutBatchRenderPath.text
		if (p == "" or not doesDirectoryExist p) do return messageBox "Please select Out Folder!" title: "Error!"
		
		p += (_rStepPPP0.upperCase type) + @"\"
		makeDir p all: true
		
		for i in 1 to 10 do (
			for id in 1 to batchRenderMgr.numViews do (
				batchRenderMgr.DeleteView id
			)
		)
		
		local postfix = "#" + (type as string)
		
		local list = _rStepPPP0.getCameraList()
		for i in list do (
			local v = batchRenderMgr.CreateView i.obj
			v.enabled = true
			v.name = i.obj.name	+ "_" + (_rStepPPP0.upperCase type)
			v.startFrame = 0
			v.endFrame = 0
			v.height = spnMinRenderHeight.value
			v.width = v.height * 6			
			v.pixelAspect = 6.0
			v.outputFilename = p + i.obj.name + postfix + "_.jpg"
			v.overridePreset = true
		)
		
		renderHeight = spnMinRenderHeight.value
		renderWidth = renderHeight * 6
		rendoutputfilename = ""
		
		actionMan.executeAction -43434444 "4096"
	)
	
	on btnSetupBatchRenderDay pressed do (
		setupBatchRender type: #day
	)
	
	on btnSetupBatchRenderNight pressed do (
		setupBatchRender type: #night
	)
	
	on btnOutBatchRenderPath pressed do (
		local p = getSaveDir()
		if (p == undefined) do return false
		
		edtOutBatchRenderPath.text = p
	)
	
	on btnStartBatchRender pressed do (
		batchRenderMgr.Render()
	)
)

rollout _rAboutPPP "About" (
    label lblName "" 
    label lblVer "" 
    
    label lblAuthor "" height: 30
    hyperlink lblCopy ""  align: #center
    
    fn getScriptInfo s releaseInfo: "" =  (
        if(releaseInfo != "") do
        (
            r = getINISetting s releaseInfo
            return r
        )

        v = getINISetting s "INFO" "VERSION"
        a = getINISetting s "INFO" "AUTHOR"
        n = getINISetting s "INFO" "NAME"
        o = getINISetting s "ABOUT"
        c = getINISetting s "INFO" "DEV"
        h = getINISetting s "INFO" "HELP"
        
        r = for i in (getINISetting s) where (i != "ABOUT" and i != "SCRIPT" and i != "COPY") collect i
        
        return #(n, a, v, o, r, c, h)
    )

    on _rAboutPPP open do (
        local i = getScriptInfo (getThisScriptFilename())
		
        lblName.caption = i[1]
        lblAuthor.caption = i[2]
        lblVer.caption = i[3]
        lblCopy.address  = lblCopy.caption = i[6]
    )
)

addRollout _rStepPPP0 fPlaycanvasPanoramaPacker rolledUp: false
addRollout _rStepPPPCustomExportCubemaps fPlaycanvasPanoramaPacker rolledUp: true
addRollout _rStepPPPBatchRender fPlaycanvasPanoramaPacker rolledUp: true
addRollout _rAboutPPP fPlaycanvasPanoramaPacker rolledUp: true 