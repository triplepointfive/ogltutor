---
title: Урок 45 - Screen Space Ambient Occlusion
---

Помните как развивалась наша модель освещения? В [уроке 17](tutorial17.html) мы увидели нашу первую модель освещения,
которая начиналась с фонового освещения. Фоновое освещение имитирует ощущение "все освещено", которое можно почуствовать
в светлый полдень. Оно было реализовано с использованием одного значения с плавающей точкой, которое прилогалось к
каждому источнику света; мы умножали на это значение на цвет текстуры поверхности. Таким образом, вы можете иметь один
источник света, названный "солнце", и вы можете поиграться с фоновым освещением для управления общей освещенностью
сцены - значение близкое к нулю создает темные сцены, а близкие к единице - яркие.

В последующих уроках мы реализовали диффузный и отраженный свет, который способствовал общему качеству сцены, но базовый
фоновый свет остался без изменений. В последние года мы видели рассвет
[Ambient occlusion](https://ru.wikipedia.org/wiki/Ambient_occlusion), который в общем означает, что вместо
фиксированного значения фонового света мы можем вычислять насколько пиксель открыт по отношению к источнику фонового
света. Пиксель в центре пола болешь подвержен влиянию источника света чем, скажем, пиксель в углу. Это значит, что угол
будет немного темнее, чем остальная часть пола. В этом вся суть ambient occlusion. Для того, что бы реализовать его
нам нужно найти способ отличать "плотно набитые в угол пиксели" от "открытых пикселей". Итогом вычислений является
ambient occlusion, который будет управлять фоновым освещением на последнем этапе освещения. Вот визуализация для
ambient occlusion:

![](/images/45/ao.jpg)

Как вы видите, ребра самые яркие, а углы, куда как мы ожидали попадет меньше всего света, ощутимо темнее.

Существует немало исследовательских работ по теме ambient occlusion и много алгоритмов, которые приблизительно его
находят. Мы собираемся изучить одно из ветвлений этих алгоритмов, известное как *Screen Space Ambient Occlusion (SSAO)*,
разработка [Crytek](http://en.wikipedia.org/wiki/Crytek), ставшее популярным в 2007 после выхода
[http://en.wikipedia.org/wiki/Crysis](Crysis). Много игр реализую свои вариации SSAO на его основе. Мы рассмотрим
самую простую версию алгоритма, основываясь на статью
[SSAO tutorial by John Chapman](http://john-chapman-graphics.blogspot.co.il/2013/01/ssao-tutorial.html).

Ambient occlusion может потребовать немало вычислительных ресурсов. Crytek пришли к компромису, где окклюзия вычисляется
один раз для пикселя. Отсюда и префикс "Пространства Экрана" в имени алгоритма. Идея была в том, что бы пробежаться по
экрану пиксель за пикселем, извлечь позицию в пространстве экрана, выбрать несколько случайных точек в окрестности этой
позиции и проверить, лежат ли эти точки внутри или снаружи геометрического объекта. Если большинство точек лежат внутри,
то исходный пиксель находится в углу, образованного несколькими полигонами, и получает меньше света. Если большинство
точек лежат снаружи, то исходный пикслеь хорошо освещен, и следовательно, получает больше света. Для примера рассмотрим
следующее изображение:

![](/images/45/algorithm.jpg)

Мы имеем поверхность с 2 точками на ней - P0 и P1. Предположим, что мы смотрим на неё откуда-то с верхнего левого угла
изображения. Мы выбираем несколько точек в окрестности каждой точки и проверяем, лежат ли они внутри или снаружи
геометрического объекта. В случае P0 шанс на то, что случаяйная точка будет внутри объекта, выше. Для P1 наоборот.
Поэтому мы ожидем большее освещение для P1, т.е. в итоге рендера точка будет ярче.

Давайте перейдем к более глубокому уровню. Мы собираемся добавить проход ambient occlusion где-то до нашего стандартного
этапа освещения (нам понадобится фоновые значения для освещения). Этап ambient occlusion будет стандартным проходом с
полноэкранным четырехугольником, где вычисления происходят один раз для пикселя. Для каждого пикселя нам нужны его
позиция в пространстве экрана и мы хотим генерировать несколько случайных точек в близкой окрестности к этой позиции.
Проще всего будет использовать текстуру, включающую в себя всю геометрию (очевидно, что только для ближайших пикселей),
заполненную позицией из пространства камеры. Для этого нам потребуется геометрический этап перед фоновым проходом, где
что-то похожее на G буфер из урока про Deferred Shading будет заполнено данными из пространства позиции камеры (на этом
все, нам не нужны нормали, цвета и т.д.). Таким образом получение позиции текущего пикслея из пространства камеры всего
лишь одна операция выборки.

Итак, теперь мы находимся во фрагментном шейдере, при этом мы имеем позицию в пространстве камеры для текущего пикселя.
Генерировать случайные точки вокруг неё очень просто. Мы будем передавать в шейдер (как uniform-переменные) массив
случайных векторов, и по одному прибавлять их к позиции пикселя. Для каждой полученной точки мы хотим проверить, лежит
ли пиксели внутри или снаружи объекта. Вспомните, что эти точки виртуальные, т.е. не стоит ожидать проверки с настоящей
поверхностью. Мы собираемся использовать что-то подобное тому, что мы использовали для карт теней. Будем сравнивать
значение Z для случайной точки со значением Z ближайшей точки исходной геометрии. Разумеется, что точка исходной
геометрии должна лежать на одном луче из камеры до виртуальной точки. Посмотрим на диаграмму:

![](/images/45/diagram1.jpg)

Точка P лежит на красной поверхности, а красная и зеленая точки были случайно созданы. Зеленая точка лежит вне (до)
объекта, а красная внутри (это используется для ambient occlusion). Окружность обозначает радиус, в котором могут
генерироваться случайные точки (мы не хотим, что бы они были слишком далеко от точки P). R1 и R2 являются лучами из
камеры (в 0,0,0) до красной и зеленой точек. Оба пересекаются с геометрическим объектом. Для того, что бы вычислить
ambient occlusion мы должны сравнить значения Z красной и зеленой точек со значением Z соответствующих точек, полученных
при пересечении объекта лучами R1/R2. У нас уже есть значения Z для красной и зеленой точек (в пространстве камеры, в
конце концов так мы их и создавали). Но какое значение Z для точек пересечения?

Что ж, существует более одного решения у этой проблемы, но поскольку у нас уже есть текстура со сначениями в
пространстве камеры для всей сцены, проще всего будет искать каким-то образом в этой текстуре. Для этого нам нужны две
координаты для лучей R1 и R2. Вспомним, что исходные координаты текстуры, которые мы использовали нахождения позиции P
не подходят. Эти координаты были сформированы при интерполяции полноэкранного прямоугольника, который мы развертываем
в этом проходе. Но лучи R1 и R2 не проходят через P. Они где-то пересекают поверхность.

Теперь нам надо быстро обновлять текстуру с позицией пространства камеры способом аналогичным тому, который мы
использовали для её создания. После переноса объекта из локального пространства в пространство камеры полученые векторы
были умножены на матрицу проекции (по факту, все эти преобразования были выполнены одной матрицей). Все это происходило
в вершинном шейдере, и на пути к фрагментному шейдеру GPU автоматически выполнило деление перспективы для завершения
проецирования. Такое проецирование размещает позицию из пространства камеры на ближайшей плоскости клиппера, а
координаты XYZ точек внутри усеченного конус лежат на отрезке (-1,1). В то время как позиция в пространстве камеры
пишется в текстуру в фрагментном шейдере (вычисления выше будут выполняться только над gl_Position; данные для записи в
текстуру будут переданы ещё одной переменной), XY переносятся на отрезок (0,1), т.е. будут использоваться для указания
позиции на текстуре, куда будет записана позиция в пространстве камеры.

Итак, можем ли мы использовать такую же процедуру для вычисления координат текстуры для красной и зеленой точек? Что-ж,
почему бы и нет? Математика остается той же самой. Все что нам требуется, это передать в шейдер матрицу проекции и
использовать её для проецирования красной и зеленой точек на ближнюю плоскость клиппера. Нам потребуется вручную
произвести деление перспективы, но в этом ничего заумного. Затем нам потребуется перенести результат на (0,1), а вот и
наши координаты текстуры! Нас отделяет только выборка значения из текстуры от получения координаты Z и проверки, будет
ли виртуальная точка лежать внутри или снаружи геометрии. Теперь перейдем к коду.

## [Прямиком к коду!](https://github.com/triplepointfive/ogldev/tree/master/tutorial45)

> tutorial45.cpp:156

    virtual void RenderSceneCB()
    {   
        m_pGameCamera-&gt;OnRender();
        m_pipeline.SetCamera(*m_pGameCamera);
        GeometryPass();
        SSAOPass();
        BlurPass();
        LightingPass();
        RenderFPS();
        CalcFPS();
        OgldevBackendSwapBuffers();
    }

We will start the source walkthru from the top level and work our way down. This is the main
render loop and in addition to the three passes that we discussed in the
background section there's also a blur pass whose job is to apply a blur
kernel on the ambient occlusion map formed by the SSAO pass. This helps smooth
things up a bit and is not part of the core algorithm. It's up to you to decide
whether to include it or not in your engine.

> tutorial45.cpp:177

    void GeometryPass()
    {
        m_geomPassTech.Enable();

        m_gBuffer.BindForWriting();

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        m_pipeline.Orient(m_mesh.GetOrientation());
        m_geomPassTech.SetWVP(m_pipeline.GetWVPTrans());
        m_geomPassTech.SetWVMatrix(m_pipeline.GetWVTrans());
        m_mesh.Render();
    }

In the geometry pass we render the entire scene into a texture. In this
example there's only one mesh. In the real world there will probably
be many meshes.

> geometry_pass.vs

    #version 330
    
    layout (location = 0) in vec3 Position;
    
    uniform mat4 gWVP;
    uniform mat4 gWV;
    
    out vec3 ViewPos;
    
    void main()
    {       
        gl_Position = gWVP * vec4(Position, 1.0);
        ViewPos     = (gWV * vec4(Position, 1.0)).xyz;
    }

> geometry_pass.fs

    #version 330
                                                                            
    in vec3 ViewPos;
    
    layout (location = 0) out vec3 PosOut;   
    
    void main()
    {
        PosOut = ViewPos;
    }

These are the vertex and fragment shaders of the geometry pass. In the vertex shader
we calculate the gl_position as usual and we pass the view
space position to the fragment shader in a separate variable. Remember that there is no perspective
divide for this variable but it is a subject to the regular interpolations performed
during rasterization.

In the fragment shader we write the interpolated view space position to the
texture. That's it.

> tutorial45.cpp:192

    void SSAOPass()
    {
        m_SSAOTech.Enable();
        m_SSAOTech.BindPositionBuffer(m_gBuffer);
        m_aoBuffer.BindForWriting();
        glClear(GL_COLOR_BUFFER_BIT);
        m_quad.Render();
    }

This is the application code of the SSAO pass and it is very simple. On the
input side we have the view space position from the previous pass and
we write the output to an AO buffer. For the rendering we use a full screen quad.
This will generate the AO term for every pixel. The real meat is in the shaders.

> ssao.vs

    #version 330
    
    layout (location = 0) in vec3 Position; 
    
    out vec2 TexCoord;
    
    void main()
    {          
        gl_Position = vec4(Position, 1.0);
        TexCoord = (Position.xy + vec2(1.0)) / 2.0;
    }

As in many screen space based techniques in the vertex shader we just need to
pass-thru the position of the full screen quad. gl_Position will be consumed
by the GPU for the purposes of rasterization but we use it's XY components for
the texture coordinates. Remember that the full screen quad coordinates
range from (-1,-1) to (1,1) so everything in the fragment shader will be interpolated
in that range. We want our texture coordinates to be in the (0,1) so we transform
it here before sending it out to the fragment shader.

> ssao.fs

    #version 330
    
    in vec2 TexCoord;
    
    out vec4 FragColor;
    
    uniform sampler2D gPositionMap;
    uniform float gSampleRad;
    uniform mat4 gProj;
    
    const int MAX_KERNEL_SIZE = 128;
    uniform vec3 gKernel[MAX_KERNEL_SIZE];
    
    void main()
    {
        vec3 Pos = texture(gPositionMap, TexCoord).xyz;

        float AO = 0.0;

        for (int i = 0 ; i &lt; MAX_KERNEL_SIZE ; i++) {
            vec3 samplePos = Pos + gKernel[i];   // generate a random point
            vec4 offset = vec4(samplePos, 1.0);  // make it a 4-vector
            offset = gProj * offset;        // project on the near clipping plane
            offset.xy /= offset.w;      // perform perspective divide
            offset.xy = offset.xy * 0.5 + vec2(0.5);    // transform to (0,1) range

            float sampleDepth = texture(gPositionMap, offset.xy).b;

            if (abs(Pos.z - sampleDepth) &lt; gSampleRad) {
                AO += step(sampleDepth,samplePos.z);
            }
        }

        AO = 1.0 - AO/128.0;

        FragColor = vec4(pow(AO, 2.0));
    }

Here's the core of the SSAO algorithm. We take the texture coordinates
we got from the vertex shader and sample the position map to fetch our view space position. Next we
enter a loop and start generating random points. This is done using an array of
uniform vectors (gKernel). This array is populated by random vectors in the
(-1,1) range in the ssao_technique.cpp file (which I haven't included here because it's pretty
standard; check the code for more details). We now need to find the texture coordinates
that will fetch the Z value for the geometry point that matches the current random point.
We project the random point from view space on the near clipping plane using the projection matrix, perform perspective divide on
it and transform it to the (0,1) range. We can now use it to sample the view space position
of the actual geometry and compare its Z value to the random point. But before we do
that we make sure that the distance between the origin point and the one whose Z value
we just fetched is not too far off. This helps us avoid all kinds of nasty artifacts.
You can play with the gSampleRad variable for that.

Next we compare the depth of the virtual point with the one from the actual
geometry. The GLSL step(x,y) function returns 0 if y &lt; x and 1 otherwise.
This means that the local variable AO increases as more points end up behind the geometry.
We plan to multiply the result by the color of the lighted pixel so we do a 'AO = 1.0 - AO/128.0'
to kind-of reverse it. The result is written to the output buffer. Note that we take
the AO to the power of 2 before writing it out. This simply makes it look a bit better in my
opinion. This is another artist variable you may want to play with in your engine.

> tutorial45.cpp:205

    void BlurPass()
    {
        m_blurTech.Enable();

        m_blurTech.BindInputBuffer(m_aoBuffer);

        m_blurBuffer.BindForWriting();

        glClear(GL_COLOR_BUFFER_BIT);

        m_quad.Render();
    }

The application code of the blur pass is identical to the SSAO pass. Here the input
is the ambient occlusionn term we just calculated and the output is a buffer
containing the blurred results.

> blur.vs

    #version 330
    
    layout (location = 0) in vec3 Position; 
    
    out vec2 TexCoord;
    
    void main()
    {          
        gl_Position = vec4(Position, 1.0);
        TexCoord = (Position.xy + vec2(1.0)) / 2.0;
    }

> blur.fs

    #version 330
    
    in vec2 TexCoord;
    
    out vec4 FragColor;
    
    uniform sampler2D gColorMap;
    
    float Offsets[4] = float[]( -1.5, -0.5, 0.5, 1.5 );
    
    void main()
    {
        vec3 Color = vec3(0.0, 0.0, 0.0);

        for (int i = 0 ; i &lt; 4 ; i++) {
            for (int j = 0 ; j &lt; 4 ; j++) {
                vec2 tc = TexCoord;
                tc.x = TexCoord.x + Offsets[j] / textureSize(gColorMap, 0).x;
                tc.y = TexCoord.y + Offsets[i] / textureSize(gColorMap, 0).y;
                Color += texture(gColorMap, tc).xyz;
            }
        }

        Color /= 16.0;

        FragColor = vec4(Color, 1.0);
    }

This is an example of a very simple blur technique. The VS is actually identical to the
one from the SSAO. In the fragment shader we sample 16 points around the origin and average
them out.

> tutorial45.cpp:219

    void LightingPass()
    {
        m_lightingTech.Enable();
        m_lightingTech.SetShaderType(m_shaderType);
        m_lightingTech.BindAOBuffer(m_blurBuffer);

        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        m_pipeline.Orient(m_mesh.GetOrientation());
        m_lightingTech.SetWVP(m_pipeline.GetWVPTrans());
        m_lightingTech.SetWorldMatrix(m_pipeline.GetWorldTrans());
        m_mesh.Render();
    }

We have a pretty standard application code for the lighting pass. The only addition
here is the blurred AO term buffer which is bound as input.

> lighting.fs

    vec2 CalcScreenTexCoord()
    {
        return gl_FragCoord.xy / gScreenSize;
    }
    
    
    vec4 CalcLightInternal(BaseLight Light, vec3 LightDirection, vec3 Normal)
    {
        vec4 AmbientColor = vec4(Light.Color, 1.0f) * Light.AmbientIntensity;

        if (gShaderType == SHADER_TYPE_SSAO) {
           AmbientColor *= texture(gAOMap, CalcScreenTexCoord()).r;
        }

        ...

I haven't included the entire lighting shader since the change is very minor.
The ambient color is modulated by the ambient occlusion term sampled from the AO map for
the current pixel. Since we are rendering the actual geometry here and not a full screen quad
we have to calculate the texture coordinates using the system maintained gl_FragCoord. gShaderType
is a user controlled variable that helps us switch from SSAO to no-SSAO and only-ambient-occlusion-term
display. Play with the 'a' key to see how it goes.

#### Использованая литература: [SSAO tutorial by John Chapman](http://john-chapman-graphics.blogspot.co.il/2013/01/ssao-tutorial.html)
