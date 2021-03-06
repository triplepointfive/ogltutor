---
title: Урок 35 - Deferred Shading - Часть 1
date: 2016-12-06 16:24:30 +0300
---

Способ, который мы использовали начиная с [17 урока](tutorial17.html) известен как *опережающий рендер (Forward Rendering) или Shading*. Это прямолинейный подход, в котором мы производим серию преобразований над вершинами всех объектов в VS (большая часть - перевод нормалей и координат в пространство клипа), за которой следует вычисление света для каждого пикселя в FS. Так как каждый пиксель используется в FS лишь раз, то мы должны обеспечить FS информацией обо всех источниках света при расчете световой эффект на пиксель. Это простой подход, но он имеет свои недостатки. При сложной сцене (как в большинстве игр) со множеством объектов и ситуациями, когда один и тот же пиксель покрывают несколько объектов, у нас будут пустые затраты ресурсов. Например, если сложность глубины 4, то 3 раза вычисления света будут происходить напрасно, поскольку нужен только верхний пиксель. Мы, конечно, можем сортировать объекты в порядке удаления от камеры, но этот способ не всегда работает для сложных объектов.

Другая проблема опережающего рендера проявляется при большом колличестве источников света. В этом случае свет, как правило, имеет не большой радиус распространения (иначе он зальет всю сцену). Но наш FS вычисляет эффект каждого источника, даже если он далеко от пикселя. Мы могли бы попробовать вычислить расстояние между ними, но это дополнительные расходы и ветвления в FS. Forward rendering просто не подходит для сцен с большим колличеством источников света. Только представь сколько вычислений будет происходить при 100 источников...

Deferred shading - популярная технология, используемая во [многих играх](http://en.wikipedia.org/wiki/Deferred_shading#Deferred_shading_in_commercial_games), решающая проблемы, описанные выше. Ключевой момент в том, что происходит разделение вычисления геометрии (преобразования позиции и нормалей) и рассчетов освещения. Вместо того, что бы все объекты проходили весь путь от веринного буффера до итогового расположения в буффере кадра, мы разделяем процесс на 2 большие части. В первом проходе мы запускаем обычный VS, но вместо отправки обработанных аттрибутов в FS для вычисления освещения, мы отправляем их в нечто под названием *G Buffer*. Внутри он состоит из набора 2D текстур, по одной на каждый аттрибут. Мы разделяем аттрибуты и записываем их в различные текстуры благодаря свойству OpenGL - *Multiple Render Targets* (MRT). Так как аттрибуты мы в дальнейшем используем в FS, то значения в G буффере - это результат интерполяции, выполненой растеризатором над аттрибутами вершин. Этот этап называется *Geometry Pass*. Каждый объект обрабатывается в этом проходе. Благодаря тесту глубины, после геометрического прохода текстуры в G буффере заполнены интерполированными аттрибутами ближайших к камере пикселей. Это значит, что все "постороннии" пиксели, которые провалили тест глубины, будут выброшены, а останутся только те, для которых следует вычислить освещение. Вот пример G буффера одного кадра:

![](/images/t35_gbuffer.jpg)

Во втором проходе (известном как *Lighting Pass*) мы пройдем по G буфферу пиксель за пикселем, получим их аттрибуты из различных текстур и произведем вычисления освещения почти так же, как делали это раньше. Так как все пиксели, кроме самых близких, были отброшенны при создании G буффера, то вычисления света будут происходить по одному разу на пиксель.

Как мы обходим G буффер пиксель за пикселем? Простейший способ - рендерить на экран прямоугольник. Но есть способ лучше. Как ранее говорилось, источника света постепенно угасают, и их эффект достигает лишь нескольких пикселей. Когда влияние света достаточно мало, то его лучше проигнорировать совсем с точки зрения производительности. В forward rendering мы ничего не можем поделать, а вот в deferred shading мы можем вычислить размер сферы вокруг источника света (для точечного света, для проектора используется конус). Эта сфера представляет сферу влияния света, и вне ее мы хотим игнорировать источник света. Мы можем использовать очень грубую модель сферы с небольшим колличеством полигонов и просто рендерить ее с источником света в центре. VS не будет делать ничего, кроме перевода позиции в пространство клипа. FS будет запущен только для подходящих пикселей, где и будут вычисления света. Некоторые идут еще дальше и находят минимальный прямоугольник, который покрывает эту сферу из точки зрения. Рендерить этот прямоугольник еще проще, так как он состоит из 2 треугольников. Этот метод полезен для ограничения колличества пикселей, для которых FS действительно нужно запускать.

Мы изучим deferred shading в 3 этапа (и 3 урока):

1. В этом уроке мы заполним G буффер используя MRT. Кроме того, для наглядности мы выведем его содержимое на экран.
2. В следующем уроке мы добавим вычисления света в стиле deferred shading.
3. И, наконец, мы изучим как использовать стенсил, что бы отбрасывать далекий свет, который не влияет на сцену (проблема станет понятней во втором уроке).

## [Прямиком к коду!](https://github.com/triplepointfive/ogldev/tree/master/tutorial35)

> gbuffer.h:28

    class GBuffer
    {
    public:

        enum GBUFFER_TEXTURE_TYPE {
        GBUFFER_TEXTURE_TYPE_POSITION,
                GBUFFER_TEXTURE_TYPE_DIFFUSE,
        GBUFFER_TEXTURE_TYPE_NORMAL,
                GBUFFER_TEXTURE_TYPE_TEXCOORD,
                GBUFFER_NUM_TEXTURES
        };

        GBuffer();

        ~GBuffer();

        bool Init(unsigned int WindowWidth, unsigned int WindowHeight);

        void BindForWriting();

        void BindForReading();

    private:

        GLuint m_fbo;
        GLuint m_textures[GBUFFER_NUM_TEXTURES];
        GLuint m_depthTexture;
    };

Класс GBuffer содержит все текстуры, которые потребуются для deferred shading. У нас есть текстуры для аттрибутов вершин, и еще текстура для буффера глубины. Она нам потребуется, так как мы хотим запаковать все текстуры в FBO, поэтому стандартный буффер глубины нам не потребуется. FBO уже был рассмотрен в [уроке 23](http://ogltutor.netau.net/tutorial23.html).

Кроме того, класс GBuffer имеет 2 метода, которые будут поочереди вызываться - BindForWriting() привязывает текстуры для геометрического прохода, а BindForReading() привязывает FBO на ввод, так что его содержимое может быть выведено на экран.

> gbuffer.cpp:48

    bool GBuffer::Init(unsigned int WindowWidth, unsigned int WindowHeight)
    {
        // Создаем FBO
        glGenFramebuffers(1, &m_fbo);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_fbo);

        // Создаем текстуры gbuffer
        glGenTextures(ARRAY_SIZE_IN_ELEMENTS(m_textures), m_textures);
        glGenTextures(1, &m_depthTexture);

        for (unsigned int i = 0 ; i < ARRAY_SIZE_IN_ELEMENTS(m_textures) ; i++) {
            glBindTexture(GL_TEXTURE_2D, m_textures[i]);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB32F, WindowWidth, WindowHeight, 0, GL_RGB, GL_FLOAT, NULL);

            glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i,
            GL_TEXTURE_2D, m_textures[i], 0);
        }

        // глубина
        glBindTexture(GL_TEXTURE_2D, m_depthTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32F, WindowWidth, WindowHeight, 0, GL_DEPTH_COMPONENT, GL_FLOAT,
                                                NULL);
        glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, m_depthTexture, 0);

        GLenum DrawBuffers[] = { GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2, GL_COLOR_ATTACHMENT3 };

        glDrawBuffers(ARRAY_SIZE_IN_ELEMENTS(DrawBuffers), DrawBuffers);

        GLenum Status = glCheckFramebufferStatus(GL_FRAMEBUFFER);

        if (Status != GL_FRAMEBUFFER_COMPLETE) {
                printf("FB error, status: 0x%x\n", Status);
                return false;
        }

        // возвращаем стандартный FBO
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);

        return true;
    }

Так мы инициализируем G буффер. Мы начинаем с создания FBO и текстур для аттрибутов вершин и буффера глубины. Текстуры для аттрибутов затем проинициализированны через:

- Создаем объект текстуры (без инициализации).
- Присоединяем текстуру к FBO на вывод.

Инициализация текстуры глубины производится отдельно так как она имеет отдельный формат и слот в FBO.

Для использования MRT нам требуется разрешить запись во все 4 текстуры. Мы делаем это через отправление массива указателей в функцию glDrawBuffers(). Этот массив дает некоторую гибкость, поскольку мы ставим GL_COLOR_ATTACHMENT6 как первый индекс, а затем, когда FS записывает в первую переменную вывода, то он пойдет в текстуру, которая подсоединена к GL_COLOR_ATTACHMENT6. Пока что нам не важна сложность этих действий, в этом уроке мы просто хотим присоединить их одну за другой.

Наконец, мы проверяем состояние FBO, что бы убедиться, что все операции прошли успешно, а затем возвращаем FBO по-умолчанию (тогда дальнейшие изменения не затронут наш G буффер). G буффер готов к использованию.

> tutorial35.cpp:101

    virtual void RenderSceneCB()
    {
        CalcFPS();

        m_scale += 0.05f;

        m_pGameCamera->OnRender();

        DSGeometryPass();
        DSLightPass();

        RenderFPS();

        glutSwapBuffers();
    }

Давайте осмотрим реализацию сверху вниз. Функция выше - главная функция рендера, и она делает не так уж и много. Она обрабатывает немного глобальных переменных, таких как счетчик кадров в секунду, обновляет камеру и т.д. Главная часть вызывает геометрический проход перед проходом света. Как я уже объяснял в этом уроке мы просто генерируем G буффер, поэтому наш световой этап на самом деле ничего не делает. Только выводит G буффер на экран.

> tutorial35.cpp:118

    void DSGeometryPass()
    {
        m_DSGeomPassTech.Enable();

        m_gbuffer.BindForGeometryPass();

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        Pipeline p;
        p.Scale(0.1f, 0.1f, 0.1f);
        p.Rotate(0.0f, m_scale, 0.0f);
        p.WorldPos(-0.8f, -1.0f, 12.0f);
        p.SetCamera(m_pGameCamera->GetPos(), m_pGameCamera->GetTarget(), m_pGameCamera->GetUp());
        p.SetPerspectiveProj(m_persProjInfo);
        m_DSGeomPassTech.SetWVP(p.GetWVPTrans());
        m_DSGeomPassTech.SetWorldMatrix(p.GetWorldTrans());
        m_mesh.Render();
    }

Мы начинаем геометрический проход с разрешения использовать соответствующую технологию и задаем объект GBuffer на запись. После этого мы очищаем G буффер (glClear() работает с текущим FBO - наш G буффер). Теперь, когда все готово, мы настраиваем преобразования и рендерим меш. В настоящей игре мы будем рендерить множество мешей, один за другим. Когда мы закончим, G буффер будет содержать аттрибуты ближайших пикселей, что позволит пройти этап света.

> tutorial35.cpp:137

    void DSLightPass()
    {
        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        m_gbuffer.BindForReading();

        GLsizei HalfWidth = (GLsizei)(WINDOW_WIDTH / 2.0f);
        GLsizei HalfHeight = (GLsizei)(WINDOW_HEIGHT / 2.0f);

        m_gbuffer.SetReadBuffer(GBuffer::GBUFFER_TEXTURE_TYPE_POSITION);
        glBlitFramebuffer(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, 0, HalfWidth, HalfHeight, GL_COLOR_BUFFER_BIT, GL_LINEAR);

        m_gbuffer.SetReadBuffer(GBuffer::GBUFFER_TEXTURE_TYPE_DIFFUSE);
        glBlitFramebuffer(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, HalfHeight, HalfWidth, WINDOW_HEIGHT, GL_COLOR_BUFFER_BIT, GL_LINEAR);

        m_gbuffer.SetReadBuffer(GBuffer::GBUFFER_TEXTURE_TYPE_NORMAL);
        glBlitFramebuffer(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, HalfWidth, HalfHeight, WINDOW_WIDTH, WINDOW_HEIGHT, GL_COLOR_BUFFER_BIT, GL_LINEAR);

        m_gbuffer.SetReadBuffer(GBuffer::GBUFFER_TEXTURE_TYPE_TEXCOORD);
        glBlitFramebuffer(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, HalfWidth, 0, WINDOW_WIDTH, HalfHeight, GL_COLOR_BUFFER_BIT, GL_LINEAR);
    }

Этап света начинается с восстановления стандартного FBO (экран) и очистки его. Затем мы привязываем FBO G буффера для чтения. Теперь мы хотим скопировать текстуры из G буффера на экран. Один из способов сделать это - написать простую программу, в которой FS будет брать сэмпл из текстуры и выводить результат. Если мы будем рисовать прямоугольник на весь экран с координатами текстуры от [0,0] до [1,1], то мы, конечно, получим, что хотели. Но есть способ лучше. OpenGL имеет средства для копирования из одного FBO в другой с помощью одного вызова и без каких-либо настроек, которые бы потребовались для других способов. Функция glBlitFramebuffer() принимает координаты источника, назначения и набор других переменных, после чего производит копирование. Для этого требуется источник привязать к GL_READ_FRAMEBUFFER, а получателя к GL_DRAW_FRAMEBUFFER (что мы и сделали в начале функции). Так как FBO может иметь несколько текстур, привязанных к его различным позициям, мы так же должны привязать конкретную текстуру к GL_READ_BUFFER (поскольку мы можем копировать текстуры только по одной). Реализация скрыта в GBuffer::SetReadBuffer(), которая будет рассмотрена позже. Первые 4 параметра в glBlitframebuffer() определяют прямоугольник в источнике - нижний X, нижний Y, верхний X, верхний Y. Следующие 4 параметра аналогичны для назначения.

Девятый параметр говорит, откуда мы хотим считывать - цвет, глубина или стенсил буффер, и может принимаеть значения GL_COLOR_BUFFER_BIT, GL_DEPTH_BUFFER_BIT, или GL_STENCIL_BUFFER_BIT. Последний параметр определяет тип масштабирования OpenGL (когда параметры источника и назначения не совпадают) - GL_NEAREST или GL_LINEAR (дает результат лучше, чем GL_NEAREST, но и требует больше ресурсов). Для буффера цвета применяется только GL_LINEAR. В примере выше видно, как мы масштабируем все текстуры в одну четверть экрана.

> geometry_pass.glsl

    struct VSInput
    {
        vec3 Position;
        vec2 TexCoord;
        vec3 Normal;
    };

    interface VSOutput
    {
        vec3 WorldPos;
        vec2 TexCoord;
        vec3 Normal;
    };

    uniform mat4 gWVP;
    uniform mat4 gWorld;

    shader VSmain(in VSInput VSin:0, out VSOutput VSout)
    {
        gl_Position = gWVP * vec4(VSin.Position, 1.0);
        VSout.TexCoord   = VSin.TexCoord;
        VSout.Normal     = (gWorld * vec4(VSin.Normal, 0.0)).xyz;
        VSout.WorldPos   = (gWorld * vec4(VSin.Position, 1.0)).xyz;
    };

    struct FSOutput
    {
        vec3 WorldPos;
        vec3 Diffuse;
        vec3 Normal;
        vec3 TexCoord;
    };

    uniform sampler2D gColorMap;

    shader FSmain(in VSOutput FSin, out FSOutput FSout)
    {
        FSout.WorldPos = FSin.WorldPos;
        FSout.Diffuse  = texture(gColorMap, FSin.TexCoord).xyz;
        FSout.Normal   = normalize(FSin.Normal);
        FSout.TexCoord = vec3(FSin.TexCoord, 0.0);
    };

    program GeometryPass
    {
        vs(410)=VSmain();
        fs(410)=FSmain();
    };

Это файл эффекта для геометрического прохода. Здесь ничего нового в VS - просто производит преобразования и передает результат в FS. FS ответственнен за MRT. Вместо вывода единственного вектора он выдает структуру из векторов. Каждый из этих векторов имеет соответствующий индекс в массиве, который был задан в glDrawBuffers(). Поэтому каждый вызов FS мы записываем в 4 текстуры G буффера.

> gbuffer.cpp:90

    void GBuffer::BindForWriting()
    {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_fbo);
    }

    void GBuffer::BindForReading()
    {
        glBindFramebuffer(GL_READ_FRAMEBUFFER, m_fbo);
    }

    void GBuffer::SetReadBuffer(GBUFFER_TEXTURE_TYPE TextureType)
    {
        glReadBuffer(GL_COLOR_ATTACHMENT0 + TextureType);
    }

Три функции выше используются для изменения состояния G буффера для соответсвия коду приложения выше.
