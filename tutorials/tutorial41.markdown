---
title: Урок 41 - Размытие (Motion Blur)
---


<p>
    Размытие (Motion Blur) - очень популярная техника для быстрых 3D игр, чья идея добавить размытия движущимся объектам.
    Это повышает чувства реализма у игрока. Размытие может быть выполнено несколькими способами. Возможна камера для
    размытия, которая основывается на движении камеры, а возможно размытие, основанное на объекте. В этом уроке мы
    рассмотрим одну из реализаций.
</p>
<p>
    Идея размытия в том, что мы можем вычислить вектор движения (Motion Vector) для каждого рендуемуего пикселя между 2
    кадрами. Взяв среднее значение вдоль этого вектора из текущего буфера цвета мы получим пиксели, которые представляют
    движение соответствующих объектов. Вот и все. Давайте углубимся в детали. Далее приведено краткое описание требуемых
    шагов, после которых мы перейдем к самому коду.
</p>
<ol>
    <li>Метод разделен на 2 этапа - проход рендера, а за ним - проход размытия.</li>
    <li>В проходе рендера мы рендерим в 2 буфера - обычный буфер цвета и буфер вектора движения. Буфер цвета хранит
        исходное изображение как если бы и не было размытия. Вектор движения представляет собой вектор для каждого
        пикселя, по сути его перемещение по экрану между текущим и предыдущим кадрами.</li>
    <li>Вектор движения вычисляется как применение матрицы WVP предыдущего кадра к VS. Мы преобразуем позицию из
        локального пространства для каждой вершины используя текущую WVP и предыдущую для передачи обоих результатов в FS.
        Мы получим интерполированные позиции в пространстве клиппера в FS и преобразуем в NDC поделив их на
        соответствующую координату W. На этом завершится их проецирование на экран, теперь можно вычесть предыдущую
        позицию из текущей и получить вектор движения. Вектор будет записан в текстуру.</li>
    <li>Проход размытия реализован через рендер прямоугольника на весь экран. Мы берем вектор движения для каждого
        пикселя в FS и затем получаем цвета из буфера цвета вдоль этого вектора (начиная из текущего пикселя).</li>
    <li>Вычисляем сумму для каждой выборки, назначая наибольший вес для текущего пикселя и наименьший для
        самого отдаленного (в этом уроке именно такая реализация, но существуют и другие).</li>
    <li>Это среднее значение результатов выборки вдоль вектора движения и создает эффект размытия. Очевидно, пиксели,
        которые не изменили позицию между кадрами, будут выглядить как и раньше, то, чего мы и хотим.</li>
</ol>
<p>
    В основе этого урока лежит склетная анимация (#38). Мы рассмотрим изменения и покажем, что нужно добавить для
    получения размытия.
</p>

<a href="https://github.com/triplepointfive/ogldev/tree/master/tutorial41"><h2>Прямиком к коду!</h2></a>


> tutorial41.cpp:175</p>
    virtual void RenderSceneCB()
{
    CalcFPS();

    m_pGameCamera-&gt;OnRender();

    <b>RenderPass();

    MotionBlurPass();</b>

    RenderFPS();

    glutSwapBuffers();
}

<p>
    Это главная функция рендера, она крайне проста. У нас имеется проход рендера для всех объектов сцены и проход
    постобработки для размытия.
</p>
> tutorial41.cpp:190</p>
    void RenderPass()
{
    <b>m_intermediateBuffer.BindForWriting();</b>

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    m_pSkinningTech-&gt;Enable();

    vector<matrix4f> Transforms;

    float RunningTime = (float)((double)GetCurrentTimeMillis() - (double)m_startTime) / 1000.0f;

    m_mesh.BoneTransform(RunningTime, Transforms);

    for (uint i = 0 ; i &lt; Transforms.size() ; i++) {
        m_pSkinningTech-&gt;SetBoneTransform(i, Transforms[i]);
        <b>m_pSkinningTech-&gt;SetPrevBoneTransform(i, m_prevTransforms[i]);</b>
    }

    m_pSkinningTech-&gt;SetEyeWorldPos(m_pGameCamera-&gt;GetPos());

    m_pipeline.SetCamera(m_pGameCamera-&gt;GetPos(),
    m_pGameCamera-&gt;GetTarget(), m_pGameCamera-&gt;GetUp());
    m_pipeline.SetPerspectiveProj(m_persProjInfo);
    m_pipeline.Scale(0.1f, 0.1f, 0.1f);

    Vector3f Pos(m_position);
    m_pipeline.WorldPos(Pos);
    m_pipeline.Rotate(270.0f, 180.0f, 0.0f);
    m_pSkinningTech-&gt;SetWVP(m_pipeline.GetWVPTrans());
    m_pSkinningTech-&gt;SetWorldMatrix(m_pipeline.GetWorldTrans());

    m_mesh.Render();

    <b>m_prevTransforms = Transforms;</b>
}
</matrix4f>
<p>
    Это наш проход рендера. Он почти такой же, как и в уроке Скелетной Анимации, изменения выделены жирным. Промежуточный
    буфер (intermediate) - простой класс, который хранит буферы цвета, глубины и вектора движения в едином буфере кадра.
    Мы уже сталкивались с этим в уроках по deferred rendering (#35-#37), поэтому на нем останавливаться не будем. За
    подробностями в исходный код. Идея в рендере в FBO, а не прямо на экран. В проходе размытия мы будем считывать из
    промежуточного буфера.</p>
<p>
    Кроме этого, мы можете увидить. что мы добавили свойство класса в класс 'Tutorial41', которое хранит вектор
    преобразований костей из предыдущего кадра. Мы поставляем его в метод скининга с текущими преобразованиями костей.
    Мы увидим, как он используется в коде GLSL.
</p>
> tutorial41.cpp:227</p>
    void MotionBlurPass()
{
    m_intermediateBuffer.BindForReading();

    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);

    m_pMotionBlurTech-&gt;Enable();

    m_quad.Render();
}

<p>
    В проходе размытия мы привязываем промежуточный буфер для чтения (т.е. рендер будет происходить на экран) и рендерим
    прямоугольник на весь экран. Каждый пиксель экрана будет обработан 1 раз и в этот момент и будет вычислен эффект
    размытия.
</p>
> skinning.glsl</p>
    struct VSInput
{
    vec3  Position;
    vec2  TexCoord;
    vec3  Normal;
    ivec4 BoneIDs;
    vec4  Weights;
};

interface VSOutput
{
    vec2 TexCoord;
    vec3 Normal;
    vec3 WorldPos;
    <b>vec4 ClipSpacePos;
    vec4 PrevClipSpacePos;</b>
};

const int MAX_BONES = 100;

uniform mat4 gWVP;
uniform mat4 gWorld;
uniform mat4 gBones[MAX_BONES];
<b>uniform mat4 gPrevBones[MAX_BONES];</b>

shader VSmain(in VSInput VSin:0, out VSOutput VSout)
{
    mat4 BoneTransform = gBones[VSin.BoneIDs[0]] * VSin.Weights[0];
    BoneTransform     += gBones[VSin.BoneIDs[1]] * VSin.Weights[1];
    BoneTransform     += gBones[VSin.BoneIDs[2]] * VSin.Weights[2];
    BoneTransform     += gBones[VSin.BoneIDs[3]] * VSin.Weights[3];

    vec4 PosL      = BoneTransform * vec4(VSin.Position, 1.0);
    vec4 ClipSpacePos = gWVP * PosL;
    gl_Position    = ClipSpacePos;
    VSout.TexCoord = VSin.TexCoord;
    vec4 NormalL   = BoneTransform * vec4(VSin.Normal, 0.0);
    VSout.Normal   = (gWorld * NormalL).xyz;
    VSout.WorldPos = (gWorld * PosL).xyz;
<b>
    mat4 PrevBoneTransform = gPrevBones[VSin.BoneIDs[0]] * VSin.Weights[0];
    PrevBoneTransform     += gPrevBones[VSin.BoneIDs[1]] * VSin.Weights[1];
    PrevBoneTransform     += gPrevBones[VSin.BoneIDs[2]] * VSin.Weights[2];
    PrevBoneTransform     += gPrevBones[VSin.BoneIDs[3]] * VSin.Weights[3];

    VSout.ClipSpacePos = ClipSpacePos;
    vec4 PrevPosL      = PrevBoneTransform * vec4(VSin.Position, 1.0);
    VSout.PrevClipSpacePos = gWVP * PrevPosL;</b>
}

<p>
    Выше мы видим изменения в VS в алгоритме скиннинга. Мы добавили uniform-массив с преобразованиями костей из
    предыдущего кадра, он будет использован для нахождения позиции текущей вершины в пространстве клиппера в предыдущем
    кадре. Эта позиция, так же, как и позиция текущей вершины в пространстве клиппера в текущем кадре, будет передана в FS.
</p>
> skinning.glsl:165</p>
    <b>struct FSOutput
{
    vec3 Color;
    vec2 MotionVector;
};</b>

shader FSmain(in VSOutput FSin, out <b>FSOutput FSOut</b>)
{
    VSOutput1 In;
    In.TexCoord = FSin.TexCoord;
    In.Normal = normalize(FSin.Normal);
    In.WorldPos = FSin.WorldPos;

    vec4 TotalLight = CalcDirectionalLight(In);

    for (int i = 0 ; i &lt; gNumPointLights ; i++) {
        TotalLight += CalcPointLight(gPointLights[i], In);
    }

    for (int i = 0 ; i &lt; gNumSpotLights ; i++) {
        TotalLight += CalcSpotLight(gSpotLights[i], In);
    }

    <b>vec4 Color = texture(gColorMap, In.TexCoord) * TotalLight;
    FSOut.Color = Color.xyz;
    vec3 NDCPos = (FSin.ClipSpacePos / FSin.ClipSpacePos.w).xyz;
    vec3 PrevNDCPos = (FSin.PrevClipSpacePos / FSin.PrevClipSpacePos.w).xyz;
    FSOut.MotionVector = (NDCPos - PrevNDCPos).xy;</b>
}

<p>
    FS техники скиннинга обновлен так, что теперь он выдает 2 вектора в 2 отдельных буфера (буферы цвета и вектора
    движения). Цвет вычисляется как обычно. Для вычисления вектора движения мы проецируем позиции в пространстве
    клиппера текущего и предыдущего кадров через деление перспективы и вычитаем один из другого.
</p>
<p>
    Заметим, что вектор позиции - всего 2D вектор. Это из-за того, что он 'живет' только на экране. Соответствующий
    буфер размытия создан с типом GL_RG для соответствия.</p>
> motion_blur.glsl</p>
    struct VSInput
{
    vec3  Position;
    vec2  TexCoord;
};

interface VSOutput
{
    vec2 TexCoord;
};


shader VSmain(in VSInput VSin:0, out VSOutput VSout)
{
    gl_Position    = vec4(VSin.Position, 1.0);
    VSout.TexCoord = VSin.TexCoord;
}

<p>
    Это VS техники размытия. Мы просто передаем позицию и координаты текстуы каждой вершины полноэкранного прямоугольника.
</p>
> motion_blur.glsl:19</p>
    
    uniform sampler2D gColorTexture;
    uniform sampler2D gMotionTexture;
    
    shader FSmain(in VSOutput FSin, out vec4 FragColor)
    {                                    
          vec2 MotionVector = (texture(gMotionTexture, FSin.TexCoord).xy) / 2.0f;
    
          vec4 Color = vec4(0.0);
    
          vec2 TexCoord = FSin.TexCoord;
    
          Color += texture(gColorTexture, TexCoord) * 0.4;
          TexCoord -= MotionVector;
          Color += texture(gColorTexture, TexCoord) * 0.3;
          TexCoord -= MotionVector;
          Color += texture(gColorTexture, TexCoord) * 0.2;
          TexCoord -= MotionVector;
          Color += texture(gColorTexture, TexCoord) * 0.1;
    
          FragColor = Color;
    }

<p>
    Вот здесь все веселье размытия. Мы берем вектор движения из текущего пикселя и используем его для выборки 4-х
    текселей из буфера цвета. Цвет текущего пикселя взят из исходной позиции и получает наибольший вес (0.4). Далее мы
    движемся вдоль координат текстуры противоположно направлению вектора движения и выбираем еще 3 текселя. Далее мы
    комбинируем их уменьшая и уменьшая вес при удалении.
</p>
<p>
    Как вы могли заметить, я разделил исходный вектор движения на 2. Вам возможно потребуется небольшой тюнинг, в том
    числе в настройке веса для получения наилучшего результата. Развлекайтесь.
</p>
<p>
    Пример возможного результата:
</p>
<img src="/images/t41_tutorial41.jpg" height="50%" width="50%">
