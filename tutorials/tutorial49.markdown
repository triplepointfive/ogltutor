---
title: Урок 49 - Cascaded Shadow Mapping
---

Давайте всмотримся в тени из [урока 47](tutorial47.html):

![](/images/49/img1.jpg)

Как вы можете заметить, качество теней не высоко. Слишком пиксилизированно. Мы уже разобрались с причиной такого
эффета и назвали его *Perspective Aliasing*, представляющей собой отображение большого
числа пикселей из пространства сцены на один пиксель карты теней. Это значит что все эти пиксели будут либо в тени,
либо освещены одновременно. Другими словами, поскольку разрешение карты теней недостаточно высоко, она не может
достаточно покрыть все пространство сцены. Самый простой способ решения - это увеличить разрешение карты теней,
но это увеличит потребление памяти нашим приложением, так что этот метод не самый лучший.

Другой способ решить эту проблему - это заметить, что тени ближе к камере в плане качества куда важнее, чем тени далеко
находящихся объектов. В любом случае, объекты на расстоянии меньше по размеру, а глаза как раз фокусируются на том, что
происходит на первом плане, а остальное воспринимается как фон. Если бы мы могли использовать детализированную карту
теней для близких объектов, и другую для удаленных, то первая карта теней должна будет покрыть только небольшой
участок, то есть, уменьшая соотношение, которое мы обсудили ранее. Кароче говоря, так и работает
*Cascaded Shadow Mapping (a.k.a CSM)*. На момент написания этого урока, CSM считается одним из лучших способов для
борьбы с Perspective Aliasing. Что же, давайте подумаем как мы могли бы это реализовать.

В целом мы собираемся разбить пирамиду обзора на несколько частей - каскадов (их не обязательно должно быть два как в
предыдущем примере). В данном уроке мы будем использовать три каскада: ближний, средний и дальний. Сам алгоритм достаточно
обобщенный, так что не составит проблем увеличить число каскадов, если понадобится. Каждый каскад будет рендериться в его
собственную карту теней. Сам алгоритм теней остаётся без изменений, за исключением того, что взятие значения глубины
из карты теней должно выбирать подходящую карту, в зависимости от растояния до зрителя. Давайте посмотрим на усеченную
пирамиду обзора:

![](/images/49/img2.png)

Как обычно, у нас есть маленькая ближняя и большая дальняя плоскости. Теперь давайте посмотрим на сцену сверху:

![](/images/49/img3.png)

Следующим шагом мы разбиваем расстояние от ближней плоскости до дальней на три части. Мы будем называть их ближней,
средней и дальней. И ещё давайте добавим направление света (стрелка справа):

![](/images/49/img4.png)

Итак, как же мы собираемся рендерить каждый каскад в отдельную карту теней? Вспомним этап теней в алгоритме карты
теней. Мы настраиваем сцену для рендера с позиции источника света. Это заключается в создании матрицы WVP с
мировыми преобразованиями объекта, преобразованиями пространства обзора для света и матрицу проекции. Так как этот
урок основывается на уроке 47, который работает с тенями направленного света, то матрица проекции будет ортогональной.
Обычно CSM используется для открытых сцен, где главный источник света это солнце, и использование направленного света
здесь естественно. Если вы посмотрите на матрицу WVP выше, то вы заметите, что первые две части (мировая и обзора)
одинаковые для всех каскадов. В конце концов, позиция объекта на сцене и параметры камеры относительно источника света
не зависят от разбиение пирамиды на каскады. Так что важна здесь только матрица проекции, поскольку она задает
область, которая будет отрендерена. А поскольку ортогональная матрица проекции задается параллелепипедом, то нам нужно
задать три различных параллелепипеда, которые будут отображены в три разных ортогональных матрицы проекции.
Все три матрицы будут использованы для получения трёх матриц WVP для рендера каждого каскада в его отдельную карту теней.

Логичнее всего было бы сделать эти рамки настолько маленькими, насколько это возможно для получения
наименьшего коэфициента отношения пикселей пространства сцены к карте теней. Для этого создадим ограничивающую
рамку для каждого каскада вдоль вектора света. Давайте добавим её к первому каскаду:

![](/images/49/img5.png)

Давайте теперь добавим ограничивающую рамку для второго каскада:

![](/images/49/img6.png)

И ещё одну для последнего каскада:

![](/images/49/img7.png)

As you can see, there is some overlap of the bounding boxes due to the orientationn of the light which
means some pixels will be rendered into more than one shadow map. There is no problem with that
as long as all the pixels of a single cascade are entirely inside a single shadow map. The selection of
the shadow map to use in the shader for shadow calculations will be based on the distance of the pixel from
the actual viewer.

Calculations of the bounding boxes that serve as the basis for the orthographic projection in the
shadow phase is the most complicated part of the algorithm. These boxes must be described in light space
because the projections come after world and view transforms (at which point the light "originates" from
the origin and points along the positive Z axis). Since the boxes will be calculated as min/max values
on all three axis they will be aligned on the light direction, which is what we need for projection. To calculate
the bounding box we need to know how each cascade looks like in light space. To do that we need to follow these
steps:

1. Calculate the eight corners of each cascade in view space. This is easy and requires simple trigonometry:

    ![](/images/49/frustum1.png)

    The above image represents an arbitrary cascade (since each cascade on its own is basically a frustum and
    shares the same field-of-view angle with the other cascades). Note that we are looking from the top
    down to the XZ plane. We need to calculate X<sub>1</sub> and
    X<sub>2</sub>:

    ![](/images/49/calc1.png)

    ![](/images/49/calc2.png)

    This gives us the X and Z components of the eight coordinates of the cascade in view space. Using
    similar math with the vertical field-of-view angle we can get the Y component and finalize the coordinates.

2. Now we need to transform the cascade coordinates from view space back to world space. Let's say that the
    viewer is oriented such that in world space the frustum looks like that (the red arrow is the light direction
    but ignore it for now):

    ![](/images/49/frustum2.png)

    In order to transform from world space to view space we multiply the world position vector by
    the view matrix (which is based on the camera location and rotation). This means that if we already
    have the coordinates of the cascade in view space we must multiply them by the inverse of the view matrix
    in order to transform them to world space:

    ![](/images/49/calc3.png)

3. With the frustum coordinates in world space we can now transform them to light space as any other object.
    Remember that the light space is exactly like view space but instead of the camera we use the light source.
    Since we are dealing with a directional light that has no origin we just need to rotate the world so that
    the light direction becomes aligned with the positive Z axis. The origin of light can simply be the origin
    of the light space coordinate system (which means we don't need any translation). If we do that using the previous
    diagram (with the red arrow being the light direction) the cascade frustum in light space should look like:

    ![](/images/49/frustum3.png)

4. With the cascade coordinates finally in light space we just need to generate a bounding box for it
    by taking the min/max values of the X/Y/Z components of the eight coordinates. This bounding box
    provides the values for the orthographic projection for rendering this cascade into its shadow map.
    By generating an orthographic projection for each cascade separately we can now render each cascade
    into different shadow map. During the light phase we will calculate the shadow factor by selecting
    a shadow map based on the distance from the viewer.

## [Прямиком к коду!](https://github.com/triplepointfive/ogldev/tree/master/tutorial49)

> ogldev_shadow_map_fbo.cpp:104

    bool CascadedShadowMapFBO::Init(unsigned int WindowWidth, unsigned int WindowHeight)
    {
          // Create the FBO
          glGenFramebuffers(1, &m_fbo);

          // Create the depth buffer
          glGenTextures(ARRAY_SIZE_IN_ELEMENTS(m_shadowMap), m_shadowMap);

          for (uint i = 0 ; i < ARRAY_SIZE_IN_ELEMENTS(m_shadowMap) ; i++) {
                glBindTexture(GL_TEXTURE_2D, m_shadowMap[i]);
                glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32, WindowWidth, WindowHeight, 0, GL_DEPTH_COMPONENT, GL_FLOAT, NULL);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_MODE, GL_NONE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
          }

          glBindFramebuffer(GL_FRAMEBUFFER, m_fbo);
          glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, m_shadowMap[0], 0);

          // Disable writes to the color buffer
          glDrawBuffer(GL_NONE);
          glReadBuffer(GL_NONE);

          GLenum Status = glCheckFramebufferStatus(GL_FRAMEBUFFER);

          if (Status != GL_FRAMEBUFFER_COMPLETE) {
              printf("FB error, status: 0x%x\n", Status);
              return false;
          }

          return true;
    }


    void CascadedShadowMapFBO::BindForWriting(uint CascadeIndex)
    {
          assert(CascadeIndex < ARRAY_SIZE_IN_ELEMENTS(m_shadowMap));
          glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_fbo);
          glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, m_shadowMap[CascadeIndex], 0);
    }


    void CascadedShadowMapFBO::BindForReading()
    {
          glActiveTexture(CASCACDE_SHADOW_TEXTURE_UNIT0);
          glBindTexture(GL_TEXTURE_2D, m_shadowMap[0]);

          glActiveTexture(CASCACDE_SHADOW_TEXTURE_UNIT1);
          glBindTexture(GL_TEXTURE_2D, m_shadowMap[1]);

          glActiveTexture(CASCACDE_SHADOW_TEXTURE_UNIT2);
          glBindTexture(GL_TEXTURE_2D, m_shadowMap[2]);
    }

The CascadedShadowMapFBO class we see above is a modification of the ShadowMapFBO class
that we have previously used for shadow mapping. The main change is that the m_shadowMap
array has space for three shadow map objects which is the number of cascades we are going
to use for this example. Here we have the three main functions of the class used to
initialize it, bind it for writing in the shadow map phase and for reading in the lighting phase.

> tutorial49.cpp:197

    virtual void RenderSceneCB()
    {
         for (int i = 0; i < NUM_MESHES ; i++) {
                m_meshOrientation[i].m_rotation.y += 0.5f;
          }

          m_pGameCamera->OnRender();

          ShadowMapPass();
          RenderPass();
          OgldevBackendSwapBuffers();
    }

The main render function in the CCM algorithm is the same as in the standard shadow mapping algorithm - first
render into the shadow maps and then use them for the actual lighting.

> tutorial49.cpp:211

    void ShadowMapPass()
    {
          CalcOrthoProjs();

          m_ShadowMapEffect.Enable();

          Pipeline p;

                  // The camera is set as the light source - doesn't change in this phase
          p.SetCamera(Vector3f(0.0f, 0.0f, 0.0f), m_dirLight.Direction, Vector3f(0.0f, 1.0f, 0.0f));

          for (uint i = 0 ; i < NUM_CASCADES ; i++) {
                // Bind and clear the current cascade
                m_csmFBO.BindForWriting(i);
                glClear(GL_DEPTH_BUFFER_BIT);

                p.SetOrthographicProj(m_shadowOrthoProjInfo[i]);

                for (int i = 0; i < NUM_MESHES ; i++) {
                      p.Orient(m_meshOrientation[i]);
                      m_ShadowMapEffect.SetWVP(p.GetWVOrthoPTrans());
                      m_mesh.Render();
                }
          }

          glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

There are a few changes in the shadow mapping phase worth noting. The first is the call to CalOrthoProjs()
at the start of the phase. This function is responsible for calculating the bounding boxes used for
orthographic projections. The next change is the loop over the cascades. Each cascade must be bound for writing,
cleared and rendered to separately. Each cascade has its own projection set up in the m_shadowOrthoProjInfo array (done by
CalcOrthoProjs). Since we don't know which mesh goes to which cascade (and it can be more than one) we have
to render the entire scene into all the cascades.

> tutorial49.cpp:238

    void RenderPass()
    {
          glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

          m_LightingTech.Enable();

          m_LightingTech.SetEyeWorldPos(m_pGameCamera->GetPos());

          m_csmFBO.BindForReading();

          Pipeline p;
          p.Orient(m_quad.GetOrientation());
          p.SetCamera(Vector3f(0.0f, 0.0f, 0.0f), m_dirLight.Direction, Vector3f(0.0f, 1.0f, 0.0f));

          for (uint i = 0 ; i < NUM_CASCADES ; i++) {
                p.SetOrthographicProj(m_shadowOrthoProjInfo[i]);
                m_LightingTech.SetLightWVP(i, p.GetWVOrthoPTrans());
          }

          p.SetCamera(m_pGameCamera->GetPos(), m_pGameCamera->GetTarget(), m_pGameCamera->GetUp());
          p.SetPerspectiveProj(m_persProjInfo);
          m_LightingTech.SetWVP(p.GetWVPTrans());
          m_LightingTech.SetWorldMatrix(p.GetWorldTrans());
          m_pGroundTex->Bind(COLOR_TEXTURE_UNIT);

          m_quad.Render();

          for (int i = 0; i < NUM_MESHES ; i++) {
                p.Orient(m_meshOrientation[i]);
                m_LightingTech.SetWVP(p.GetWVPTrans());
                m_LightingTech.SetWorldMatrix(p.GetWorldTrans());
                m_mesh.Render();
          }
    }

The only change in the lighting phase is that instead of a single light WVP matrix we have three.
They are identical except for the projection part. We set them up accordingly in the loop at the middle
of the phase.

> tutorial49.cpp:80

    m_cascadeEnd[0] = m_persProjInfo.zNear;
    m_cascadeEnd[1] = 25.0f,
    m_cascadeEnd[2] = 90.0f,
    m_cascadeEnd[3] = m_persProjInfo.zFar;

Before we study how to calculate the orthographic projections we need to take a look
at the m_cascadeEnd array (which is set up as part of the constructor). This array defines the
cascades by placing the near Z and far Z in the first and last slots, respectively, and the ends of
the cascades in between. So the first cascade ends in the value of slot one, the second in slot two
and the last cascade ends with the far Z in the last slot. We need the near Z in the first slot to simplify
the calculations later.

> tutorial49.cpp:317

    void CalcOrthoProjs()
    {
          Pipeline p;

          // Get the inverse of the view transform
          p.SetCamera(m_pGameCamera->GetPos(), m_pGameCamera->GetTarget(), m_pGameCamera->GetUp());
          Matrix4f Cam = p.GetViewTrans();
          Matrix4f CamInv = Cam.Inverse();

          // Get the light space tranform
          p.SetCamera(Vector3f(0.0f, 0.0f, 0.0f), m_dirLight.Direction, Vector3f(0.0f, 1.0f, 0.0f));
          Matrix4f LightM = p.GetViewTrans();

          float ar = m_persProjInfo.Height / m_persProjInfo.Width;
          float tanHalfHFOV = tanf(ToRadian(m_persProjInfo.FOV / 2.0f));
          float tanHalfVFOV = tanf(ToRadian((m_persProjInfo.FOV * ar) / 2.0f));

          for (uint i = 0 ; i < NUM_CASCADES ; i++) {
                float xn = m_cascadeEnd[i]     * tanHalfHFOV;
                float xf = m_cascadeEnd[i + 1] * tanHalfHFOV;
                float yn = m_cascadeEnd[i]     * tanHalfVFOV;
                float yf = m_cascadeEnd[i + 1] * tanHalfVFOV;

                Vector4f frustumCorners[NUM_FRUSTUM_CORNERS] = {
                      // near face
                      Vector4f(xn,   yn, m_cascadeEnd[i], 1.0),
                      Vector4f(-xn,  yn, m_cascadeEnd[i], 1.0),
                      Vector4f(xn,  -yn, m_cascadeEnd[i], 1.0),
                      Vector4f(-xn, -yn, m_cascadeEnd[i], 1.0),

                      // far face
                      Vector4f(xf,   yf, m_cascadeEnd[i + 1], 1.0),
                      Vector4f(-xf,  yf, m_cascadeEnd[i + 1], 1.0),
                      Vector4f(xf,  -yf, m_cascadeEnd[i + 1], 1.0),
                      Vector4f(-xf, -yf, m_cascadeEnd[i + 1], 1.0)
                };

What we see above matches step #1 of the description in the background section on how to
calculate the orthographic projections for the cascades. The frustumCorners array is populated with
the eight corners of each cascade in view space. Note that since the field of view is provided only
for the horizontal axis we have to extrapolate it for the vertical axis (e.g, if the horizontal field of
view is 90 degrees and the window has a width of 1000 and a height of 500 the vertical field of view
will be only 45 degrees).

                Vector4f frustumCornersL[NUM_FRUSTUM_CORNERS];

                float minX = std::numeric_limits<float>::max();
                float maxX = std::numeric_limits<float>::min();
                float minY = std::numeric_limits<float>::max();
                float maxY = std::numeric_limits<float>::min();
                float minZ = std::numeric_limits<float>::max();
                float maxZ = std::numeric_limits<float>::min();

                for (uint j = 0 ; j < NUM_FRUSTUM_CORNERS ; j++) {
                      // Transform the frustum coordinate from view to world space
                      Vector4f vW = CamInv * frustumCorners[j];
                      // Transform the frustum coordinate from world to light space
                      frustumCornersL[j] = LightM * vW;

                       minX = min(minX, frustumCornersL[j].x);
                      maxX = max(maxX, frustumCornersL[j].x);
                      minY = min(minY, frustumCornersL[j].y);
                      maxY = max(maxY, frustumCornersL[j].y);
                      minZ = min(minZ, frustumCornersL[j].z);
                      maxZ = max(maxZ, frustumCornersL[j].z);
               }

The above code contains step #2 until #4. Each frustum corner coordinate is multiplied
by the inverse view transform in order to bring it into world  space. It is then
multiplied by the light transform in order to move it into light space. We then use
a series of min/max functions in order to find the size of the bounding box of the cascade in
light space.

                m_shadowOrthoProjInfo[i].r = maxX;
                m_shadowOrthoProjInfo[i].l = minX;
                m_shadowOrthoProjInfo[i].b = minY;
                m_shadowOrthoProjInfo[i].t = maxY;
                m_shadowOrthoProjInfo[i].f = maxZ;
                m_shadowOrthoProjInfo[i].n = minZ;
  		}
	}

The current entry in the m_shadowOrthoProjInfo array is populated using the values
of the bounding box.

> csm.vs

    #version 330

    layout (location = 0) in vec3 Position;
    layout (location = 1) in vec2 TexCoord;
    layout (location = 2) in vec3 Normal;

    uniform mat4 gWVP;

    void main()
    {
          gl_Position = gWVP * vec4(Position, 1.0);
    }

> csm.fs

    #version 330

    void main()
    {
    }

There is nothing new in the vertex and fragment shaders of the shadow map phase. We just need to
render the depth.

> lighting.vs

    #version 330

    layout (location = 0) in vec3 Position;
    layout (location = 1) in vec2 TexCoord;
    layout (location = 2) in vec3 Normal;

    const int NUM_CASCADES = 3;

    uniform mat4 gWVP;
    uniform mat4 gLightWVP[NUM_CASCADES];
    uniform mat4 gWorld;

    out vec4 LightSpacePos[NUM_CASCADES];
    out float ClipSpacePosZ;
    out vec2 TexCoord0;
    out vec3 Normal0;
    out vec3 WorldPos0;

    void main()
    {
          vec4 Pos = vec4(Position, 1.0);

          gl_Position = gWVP * Pos;

          for (int i = 0 ; i < NUM_CASCADES ; i++) {
                LightSpacePos[i] = gLightWVP[i] * Pos;
          }

          ClipSpacePosZ = gl_Position.z;
          TexCoord0     = TexCoord;
          Normal0       = (gWorld * vec4(Normal, 0.0)).xyz;
          WorldPos0     = (gWorld * vec4(Position, 1.0)).xyz;
    }

Let's review the changes in the vertex shader of the lighting phase. Instead
of a single position in light space we are going to output one for each cascade
and select the proper one for each pixel in the fragment shader. You can optimize this
later but for educational purposes I found this to be the simplest way to go. Remember
that you cannot select the cascade in the vertex shader anyway because a triangle
can be cross cascade. So we have three light space WVP matrices and we output
three light space positions. In addition, we also output the Z component of
the clip space coordinate. We will use this in the fragment shader to select
the cascade. Note that this is calculated in view space and not light space.

> lighting.fs

    const int NUM_CASCADES = 3;

    in vec4 LightSpacePos[NUM_CASCADES];
    in float ClipSpacePosZ;

    uniform sampler2D gShadowMap[NUM_CASCADES];
    uniform float gCascadeEndClipSpace[NUM_CASCADES];

The fragment shader of the lighting phase requires some changes/additions in
the general section. We get the three light space positions calculated by
the vertex shader as input as well as the Z component of the clip space coordinate.
Instead of a single shadow map we now have three. In addition, the application must supply
the end of each cascade in clip space. We will see later how to calculate this. For now
just assume that it is available.

    float CalcShadowFactor(int CascadeIndex, vec4 LightSpacePos)
    {
          vec3 ProjCoords = LightSpacePos.xyz / LightSpacePos.w;

          vec2 UVCoords;
          UVCoords.x = 0.5 * ProjCoords.x + 0.5;
          UVCoords.y = 0.5 * ProjCoords.y + 0.5;

          float z = 0.5 * ProjCoords.z + 0.5;
          float Depth = texture(gShadowMap[CascadeIndex], UVCoords).x;

          if (Depth < z + 0.00001)
                return 0.5;
          else
                return 1.0;
    }

    void main()
    {
          float ShadowFactor = 0.0;

          for (int i = 0 ; i < NUM_CASCADES ; i++) {
                if (ClipSpacePosZ <= gCascadeEndClipSpace[i]) {
                      ShadowFactor = CalcShadowFactor(i, LightSpacePos[i]);
                      break;
                }
         }
         ...

In order to find out the proper cascade for the current pixel
we traverse the uniform gCascadeEndClipSpace array and compare the Z component of the
clip space coordinate to each entry. The array is sorted from the closest cascade to
the furthest. We stop as soon as we find an entry whose value is greater than or equal
to that Z component. We then call the CalcShadowFactor() function and pass in the index of the
cascade we found. The only change to CalcShadowFactor() is that it samples the depth from the
shadow map which matches that index. Everything else is the same.

> tutorial49.cpp:134

        for (uint i = 0 ; i < NUM_CASCADES ; i++) {
              Matrix4f Proj;
              Proj.InitPersProjTransform(m_persProjInfo);
              Vector4f vView(0.0f, 0.0f, m_cascadeEnd[i + 1], 1.0f);
              Vector4f vClip = Proj * vView;
              m_LightingTech.SetCascadeEndClipSpace(i, vClip.z);
        }

The last piece of the puzzle is to prepare the values for the gCascadeEndClipSpace array.
For this we simply take the (0, 0, Z) coordinate where Z is the end of the cascade in view space.
We project it using our standard perspective projection transform to move it into clip space.
We do this for each cascade in order to calculate the end of every cascade in clip space.

If you study the tutorial sample code you will see that I've added a cascade indicator
by adding a red, green or blue color to each cascade to make them stand out. This is
very useful for debugging because you can actually see the extent of each cascade.
With the CSM algorithm (and the cascade indicator) the scene should now look like this:

![](/images/49/final.jpg)
