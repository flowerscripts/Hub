local library = sharedRequire('UILibrary.lua');
local Utility = sharedRequire('utils/Utility.lua');
local Services = sharedRequire('utils/Services.lua');

	local RunService, UserInputService, HttpService = Services:Get('RunService', 'UserInputService', 'HttpService');

	local EntityESP = {};

	local worldToViewportPoint = clonefunction(Instance.new('Camera').WorldToViewportPoint);
	local vectorToWorldSpace = CFrame.new().VectorToWorldSpace;
	local getMouseLocation = clonefunction(UserInputService.GetMouseLocation);

	local id = HttpService:GenerateGUID(false);
	local userId = "1234"

	local lerp = Color3.new().lerp;
	local flags = library.flags;

	local vector3New = Vector3.new;
	local Vector2New = Vector2.new;

	local mathFloor = math.floor;

	local mathRad = math.rad;
	local mathCos = math.cos;
	local mathSin = math.sin;
	local mathAtan2 = math.atan2;

	local showTeam;
	local allyColor;
	local enemyColor;
	local maxEspDistance;
	local toggleBoxes;
	local toggleTracers;
	local unlockTracers;
	local showHealthBar;
	local proximityArrows;
	local maxProximityArrowDistance;

	local scalarPointAX, scalarPointAY;
	local scalarPointBX, scalarPointBY;

	local labelOffset, tracerOffset;
	local boxOffsetTopRight, boxOffsetBottomLeft;

	local healthBarOffsetTopRight, healthBarOffsetBottomLeft;
	local healthBarValueOffsetTopRight, healthBarValueOffsetBottomLeft;

	local realGetRPProperty;

	local getRPProperty;
	local destroyRP;

	local scalarSize = 20;

	local ESP_RED_COLOR, ESP_GREEN_COLOR = Color3.fromRGB(192, 57, 43), Color3.fromRGB(39, 174, 96)
	local TRIANGLE_ANGLE = mathRad(45);

	do --// Entity ESP
		EntityESP = {};
		EntityESP.__index = EntityESP;
		EntityESP.__ClassName = 'entityESP';

		EntityESP.id = 0;

		local emptyTable = {};

		function EntityESP.new(player)
			EntityESP.id += 1;

			local self = setmetatable({}, EntityESP);

			self._id = EntityESP.id;
			self._player = player;
			self._playerName = player.Name;

			self._triangle = Drawing.new('Triangle');
			self._triangle.Visible = true;
			self._triangle.Thickness = 0;
			self._triangle.Color = Color3.fromRGB(255, 255, 255);
			self._triangle.Filled = true;

			self._label = Drawing.new('Text');
			self._label.Visible = false;
			self._label.Center = true;
			self._label.Outline = true;
			self._label.Text = '';
			self._label.Font = Drawing.Fonts[library.flags.espFont];
			self._label.Size = library.flags.textSize;
			self._label.Color = Color3.fromRGB(255, 255, 255);

			self._box = Drawing.new('Quad');
			self._box.Visible = false;
			self._box.Thickness = 1;
			self._box.Filled = false;
			self._box.Color = Color3.fromRGB(255, 255, 255);

			self._healthBar = Drawing.new('Quad');
			self._healthBar.Visible = false;
			self._healthBar.Thickness = 1;
			self._healthBar.Filled = false;
			self._healthBar.Color = Color3.fromRGB(255, 255, 255);

			self._healthBarValue = Drawing.new('Quad');
			self._healthBarValue.Visible = false;
			self._healthBarValue.Thickness = 1;
			self._healthBarValue.Filled = true;
			self._healthBarValue.Color = Color3.fromRGB(0, 255, 0);

			self._line = Drawing.new('Line');
			self._line.Visible = false;
			self._line.Color = Color3.fromRGB(255, 255, 255);

			for i, v in next, self do
				if (typeof(v) == 'table' and rawget(v, '__OBJECT')) then
					rawset(v, '_cache', {});
			 	end;
			end;

			self._labelObject = self._label;

			return self;
		end;

		function EntityESP:Plugin()
			return emptyTable;
		end;

		function EntityESP:ConvertVector(...)
			 if (flags.twoDimensionsESP) then
			 return vector3New(...);
			 else
			return vectorToWorldSpace(self._cameraCFrame, vector3New(...));
			 end;
		end;

		function EntityESP:GetOffsetTrianglePosition(closestPoint, radiusOfDegree)
			local cosOfRadius, sinOfRadius = mathCos(radiusOfDegree), mathSin(radiusOfDegree);
			local closestPointX, closestPointY = closestPoint.X, closestPoint.Y;

			local sameBCCos = (closestPointX + scalarPointBX * cosOfRadius);
			local sameBCSin = (closestPointY + scalarPointBX * sinOfRadius);

			local sameACSin = (scalarPointAY * sinOfRadius);
			local sameACCos = (scalarPointAY * cosOfRadius)

			local pointX1 = (closestPointX + scalarPointAX * cosOfRadius) - sameACSin;
			local pointY1 = closestPointY + (scalarPointAX * sinOfRadius) + sameACCos;

			local pointX2 = sameBCCos - (scalarPointBY * sinOfRadius);
			local pointY2 = sameBCSin + (scalarPointBY * cosOfRadius);

			local pointX3 = sameBCCos - sameACSin;
			local pointY3 = sameBCSin + sameACCos;

			return Vector2New(mathFloor(pointX1), mathFloor(pointY1)), Vector2New(mathFloor(pointX2), mathFloor(pointY2)), Vector2New(mathFloor(pointX3), mathFloor(pointY3));
		end;

		function EntityESP:Update(t)
			local camera = self._camera;
			if(not camera) then return self:Hide() end;

			local character, maxHealth, floatHealth, health, rootPart = Utility:getCharacter(self._player);
			if(not character) then return self:Hide() end;

			rootPart = rootPart or Utility:getRootPart(self._player);
			if(not rootPart) then return self:Hide() end;

			local rootPartPosition = rootPart.Position;

			local labelPos, visibleOnScreen = worldToViewportPoint(camera, rootPartPosition + labelOffset);
			local triangle = self._triangle;

			local isTeamMate = Utility:isTeamMate(self._player);
			if(isTeamMate and not showTeam) then return self:Hide() end;

			local distance = (rootPartPosition - self._cameraPosition).Magnitude;
			if(distance > maxEspDistance) then return self:Hide() end;

			local espColor = isTeamMate and allyColor or enemyColor;
			local canView = false;

			if (proximityArrows and not visibleOnScreen and distance < maxProximityArrowDistance) then
				local vectorUnit;

				if (labelPos.Z < 0) then
					vectorUnit = -(Vector2.new(labelPos.X, labelPos.Y) - self._viewportSizeCenter).Unit; --PlayerPos-Center.Unit
				else
					vectorUnit = (Vector2.new(labelPos.X, labelPos.Y) - self._viewportSizeCenter).Unit; --PlayerPos-Center.Unit
				end;

				local degreeOfCorner = -mathAtan2(vectorUnit.X, vectorUnit.Y) - TRIANGLE_ANGLE;
				local closestPointToPlayer = self._viewportSizeCenter + vectorUnit * scalarSize --screenCenter+unit*scalar (Vector 2)

				local pointA, pointB, pointC = self:GetOffsetTrianglePosition(closestPointToPlayer, degreeOfCorner);

				setrenderproperty(triangle, 'PointA', pointA);
				setrenderproperty(triangle, 'PointB', pointB);
				setrenderproperty(triangle, 'PointC', pointC);
				--triangle.PointA = pointA
				--triangle.PointB = pointB
				--triangle.PointC = pointC

				setrenderproperty(triangle, 'Color', espColor);
				triangle.Color = espColor
				canView = true;
			end;

			setrenderproperty(triangle, 'Visible', canView);
			triangle.Visible = canView
			if (not visibleOnScreen) then return self:Hide(true) end;

			self._visible = visibleOnScreen;

			local label, box, line, healthBar, healthBarValue = self._label, self._box, self._line, self._healthBar, self._healthBarValue;
			local pluginData = self:Plugin();

			local text = '[' .. (pluginData.playerName or self._playerName) .. '] [' .. mathFloor(distance) .. ']\n[' .. mathFloor(health) .. '/' .. mathFloor(maxHealth) .. '] [' .. mathFloor(floatHealth) .. ' %]' .. (pluginData.text or '') .. ' [' .. userId .. ']';

			setrenderproperty(label, 'Visible', visibleOnScreen);
			setrenderproperty(label, 'Position', Vector2New(labelPos.X, labelPos.Y - getrenderproperty(self._labelObject, 'TextBounds').Y));
			setrenderproperty(label, 'Text', text);
			setrenderproperty(label, 'Color', espColor);
			--label.Visible = visibleOnScreen
			--label.Position = Vector2New(labelPos.X, labelPos.Y - label.TextBounds.Y)
			--label.Text = text
			--label.Color = espColor

			if(toggleBoxes) then
				local boxTopRight = worldToViewportPoint(camera, rootPartPosition + boxOffsetTopRight);
				local boxBottomLeft = worldToViewportPoint(camera, rootPartPosition + boxOffsetBottomLeft);

				local topRightX, topRightY = boxTopRight.X, boxTopRight.Y;
				local bottomLeftX, bottomLeftY = boxBottomLeft.X, boxBottomLeft.Y;

				setrenderproperty(box, 'Visible', visibleOnScreen);

				setrenderproperty(box, 'PointA', Vector2New(topRightX, topRightY));
				setrenderproperty(box, 'PointB', Vector2New(bottomLeftX, topRightY));
				setrenderproperty(box, 'PointC', Vector2New(bottomLeftX, bottomLeftY));
				setrenderproperty(box, 'PointD', Vector2New(topRightX, bottomLeftY));
				setrenderproperty(box, 'Color', espColor);

				-- box.Visible = visibleOnScreen

				-- box.PointA = Vector2New(topRightX, topRightY)
				-- box.PointB = Vector2New(bottomLeftX, topRightY)
				-- box.PointC = Vector2New(bottomLeftX, bottomLeftY)
				-- box.PointD = Vector2New(topRightX, bottomLeftY)
				-- box.Color = espColor
			else
				setrenderproperty(box, 'Visible', false);
			end;

			if(toggleTracers) then
				local linePosition = worldToViewportPoint(camera, rootPartPosition + tracerOffset);

				setrenderproperty(line, 'Visible', visibleOnScreen);


				setrenderproperty(line, 'From', unlockTracers and getMouseLocation(UserInputService) or self._viewportSize);
				setrenderproperty(line, 'To', Vector2New(linePosition.X, linePosition.Y));
				setrenderproperty(line, 'Color', espColor);

				-- line.Visible = visibleOnScreen

				-- line.From = unlockTracers and getMouseLocation(UserInputService) or self._viewportSize
				-- line.To = Vector2New(linePosition.X, linePosition.Y)
				-- line.Color = espColor
			else
				setrenderproperty(line, 'Visible', false);
				--line.Visible = false
			end;

			if(showHealthBar) then
				local healthBarValueHealth = (1 - (floatHealth / 100)) * 7.4;

				local healthBarTopRight = worldToViewportPoint(camera, rootPartPosition + healthBarOffsetTopRight);
				local healthBarBottomLeft = worldToViewportPoint(camera, rootPartPosition + healthBarOffsetBottomLeft);

				local healthBarTopRightX, healthBarTopRightY = healthBarTopRight.X, healthBarTopRight.Y;
				local healthBarBottomLeftX, healthBarBottomLeftY = healthBarBottomLeft.X, healthBarBottomLeft.Y;

				local healthBarValueTopRight = worldToViewportPoint(camera, rootPartPosition + healthBarValueOffsetTopRight - self:ConvertVector(0, healthBarValueHealth, 0));
				local healthBarValueBottomLeft = worldToViewportPoint(camera, rootPartPosition - healthBarValueOffsetBottomLeft);

				local healthBarValueTopRightX, healthBarValueTopRightY = healthBarValueTopRight.X, healthBarValueTopRight.Y;
				local healthBarValueBottomLeftX, healthBarValueBottomLeftY = healthBarValueBottomLeft.X, healthBarValueBottomLeft.Y;
					--[[
					
						healthBar.Visible = visibleOnScreen
						healthBar.Color = espColor

						healthBar.PointA = Vector2New(healthBarTopRightX, healthBarTopRightY)
						healthBar.PointB = Vector2New(healthBarBottomLeftX, healthBarTopRightY)
						healthBar.PointC = Vector2New(healthBarBottomLeftX, healthBarBottomLeftY)
						healthBar.PointD = Vector2New(healthBarTopRightX, healthBarBottomLeftY)

						healthBarValue.Visible = visibleOnScreen
						healthBarValue.Color = lerp(ESP_RED_COLOR, ESP_GREEN_COLOR, floatHealth / 100)

						healthBarValue.PointA = Vector2New(healthBarValueTopRightX, healthBarValueTopRightY)
						healthBarValue.PointB = Vector2New(healthBarValueBottomLeftX, healthBarValueTopRightY)
						healthBarValue.PointC = Vector2New(healthBarValueBottomLeftX, healthBarValueBottomLeftY)
						healthBarValue.PointD = Vector2New(healthBarValueTopRightX, healthBarValueBottomLeftY)
					]]


				setrenderproperty(healthBar, 'Visible', visibleOnScreen);
					setrenderproperty(healthBar, 'Color', espColor);

		
					setrenderproperty(healthBar, 'PointA', Vector2New(healthBarTopRightX, healthBarTopRightY));
					setrenderproperty(healthBar, 'PointB', Vector2New(healthBarBottomLeftX, healthBarTopRightY));
					setrenderproperty(healthBar, 'PointC', Vector2New(healthBarBottomLeftX, healthBarBottomLeftY));
					setrenderproperty(healthBar, 'PointD', Vector2New(healthBarTopRightX, healthBarBottomLeftY));
		
					setrenderproperty(healthBarValue, 'Visible', visibleOnScreen);
					setrenderproperty(healthBarValue, 'Color', lerp(ESP_RED_COLOR, ESP_GREEN_COLOR, floatHealth / 100));
		
					setrenderproperty(healthBarValue, 'PointA', Vector2New(healthBarValueTopRightX, healthBarValueTopRightY));
					setrenderproperty(healthBarValue, 'PointB', Vector2New(healthBarValueBottomLeftX, healthBarValueTopRightY));
					setrenderproperty(healthBarValue, 'PointC', Vector2New(healthBarValueBottomLeftX, healthBarValueBottomLeftY));
					setrenderproperty(healthBarValue, 'PointD', Vector2New(healthBarValueTopRightX, healthBarValueBottomLeftY));



			else
				setrenderproperty(healthBar, 'Visible', false);
				setrenderproperty(healthBarValue, 'Visible', false);

				-- healthBar.Visible = false
				-- healthBarValue.Visible = false

			end;
		end;

		function EntityESP:Destroy()
			if (not self._label) then return end;

			--destroyRP(self._label);
			--self._label = nil;
			self._label:Destroy()
			--destroyRP(self._box);
			--self._box = nil;
			self._box:Destroy()
			--destroyRP(self._line);
			-- self._line = nil;
			self._line:Destroy()
			-- destroyRP(self._healthBar);
			--self._healthBar = nil;
			self._healthBar:Destroy()
			--destroyRP(self._healthBarValue);
			--self._healthBarValue = nil;
			self._healthBarValue:Destroy()
			-- destroyRP(self._triangle);
			-- self._triangle = nil;
			self._triangle:Destroy()
		end;


		function EntityESP:Hide(bypassTriangle)
			if (not bypassTriangle) then
				setrenderproperty(self._triangle, 'Visible', false);
				self._triangle.Visible = false
			end;

			if (not self._visible) then return end;
			self._visible = false;

			setrenderproperty(self._label, 'Visible', false);
			setrenderproperty(self._box, 'Visible', false);
			setrenderproperty(self._line, 'Visible', false);

			setrenderproperty(self._healthBar, 'Visible', false);
			setrenderproperty(self._healthBarValue, 'Visible', false);


			self._label.Visible = false
			self._box.Visible = false
			self._line.Visible = false

			self._healthBar.Visible = false
			self._healthBarValue.Visible = false

		end;

		function EntityESP:SetFont(font)
			setrenderproperty(self._label, 'Font', font);
			--self._label.Font = font
		end;

		function EntityESP:SetTextSize(textSize)
			setrenderproperty(self._label, 'Size', textSize);
			--self._label.Size = textSize
		end;

		local function updateESP()
			local camera = workspace.CurrentCamera;
			EntityESP._camera = camera;
			if (not camera) then return end;

			EntityESP._cameraCFrame = EntityESP._camera.CFrame;
			EntityESP._cameraPosition = EntityESP._cameraCFrame.Position;

			local viewportSize = camera.ViewportSize;

			EntityESP._viewportSize = Vector2New(viewportSize.X / 2, viewportSize.Y - 10);
			EntityESP._viewportSizeCenter = viewportSize / 2;

			showTeam = flags.showTeam;
			allyColor = flags.allyColor;
			enemyColor = flags.enemyColor;
			maxEspDistance = flags.maxEspDistance;
			toggleBoxes = flags.toggleBoxes;
			toggleTracers = flags.toggleTracers;
			unlockTracers = flags.unlockTracers;
			showHealthBar = flags.showHealthBar;
			maxProximityArrowDistance = flags.maxProximityArrowDistance;
			proximityArrows = flags.proximityArrows;

			scalarSize = library.flags.proximityArrowsSize or 20;

			scalarPointAX, scalarPointAY = scalarSize, scalarSize;
			scalarPointBX, scalarPointBY = -scalarSize, -scalarSize;

			labelOffset = EntityESP:ConvertVector(0, 3.25, 0);
			tracerOffset = EntityESP:ConvertVector(0, -4.5, 0);

			boxOffsetTopRight = EntityESP:ConvertVector(2.5, 3, 0);
			boxOffsetBottomLeft = EntityESP:ConvertVector(-2.5, -4.5, 0);

			healthBarOffsetTopRight = EntityESP:ConvertVector(-3, 3, 0);
			healthBarOffsetBottomLeft = EntityESP:ConvertVector(-3.5, -4.5, 0);

			healthBarValueOffsetTopRight = EntityESP:ConvertVector(-3.05, 2.95, 0);
			healthBarValueOffsetBottomLeft = EntityESP:ConvertVector(3.45, 4.45, 0);
		end;

		updateESP();
		RunService:BindToRenderStep(id, Enum.RenderPriority.Camera.Value, updateESP);
	end;

	return EntityESP;
