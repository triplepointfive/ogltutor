---
title: Урок 25 - Скайбокс
date: 2016-12-06 16:24:30 +0300
---

Скайбокс - это метод, который визуально увеличивает сцену, делает ее более выразительной создав текстуру вокруг зрителя, которая окружает камеру на 360 градусов. Текстура часто является комбинацией неба и местности, такой как горы, небоскребы и прочее. Во время изучения окрестностей игроком, он увидит часть скайбокса, который заполняет пустые пиксели, не покрытые обычными моделями. Вот пример скайбокса из Half-Life:

![](/images/t25_Halflife_skybox.jpg)

Идея скайбокса в рендере большого куба и размещение зрителя в центре. При движении камеры куб следует за ней, поэтому зритель никогда не достигнет "горизонта" сцены. Это похоже на реальный мир, где мы видим как облака "касаются" земли на горизонте, но когда мы движемся вперед, горизонт остается на том же расстоянии (в зависимости от рельефа).

Специальный вид текстур отображается на куб. Эта текстура создается таким образом, что если ее разрезать и правильно сложить, то ее границы совпадут по рисунку друг с другом, и для того, кто внутри, будет ощущение, что текстура литая. Например вот эта текстура:

![](/images/t25_skybox.jpg)

Если мы вырежем белые области текстуры выше и сложим оставшиеся части вдоль белых линий, то мы получим куб, который удовлетворяет нашим требованиям. В OpenGL у таких текстур есть специальное название *Кубическая текстура (Cubemap)*.

Для того что бы взять сэмпл из кубической текстуры, мы будем использовать 3D координаты текстуры вместо 2D, которые мы уже так давно используем. Сэмпл текстуры будет использовать эти координаты в качестве вектора и сначала проверит какая из 6 сторон содержит данный тексел, а затем вытащит его из этой грани. Процесс может быть виден на следующем изображении (смотрим сверху вниз на коробку):

![](/images/t25_texel_fetch.png)

Выбор стороны основывается на наибольшей по значению координате текстуры. В примере выше мы видим, что Z имеет наибольшее значение (мы не можем видеть Y, но предположим, что он меньше Z). Так как Z имеет положительный знак, то будет использована грань, у которой текстура помечена как 'PosZ', и тексел будет браться из нее (другие стороны - это 'NegZ', 'PosX', 'NegX', 'PosY' и 'NegY').

Метод скайбокса может быть так же представлен через сферу вместо куба. Вся разница в том, что длина вектора во всех возможных направлениях одинакова (так как это радиус сферы), в то время как у куба длина различная. Механизм выбора текселя не изменился. Скайбокс, в котором вместо куба - сфера еще называют *skydome*. Вот что мы будем использовать в демо к уроку. Вам следует попробовать оба варианта и выбрать наиболее подходящий.

## [Прямиком к коду!](https://github.com/triplepointfive/ogldev/tree/master/tutorial25)

> cubemap_texture.h:28

    class CubemapTexture
    {
    public:

        CubemapTexture(const string& Directory,
            const string& PosXFilename,
            const string& NegXFilename,
            const string& PosYFilename,
            const string& NegYFilename,
            const string& PosZFilename,
            const string& NegZFilename);

        ~CubemapTexture();

        bool Load();

        void Bind(GLenum TextureUnit);

    private:

        string m_fileNames[6];
        GLuint m_textureObj;
    };

Этот класс включает в себя реализацию кубической текстуры и предоставляет простой интерфейс для ее загрузки и использования. Конструктор принимает директорию и 6 имен файлов, которые содержат стороны куба. Для удобства мы предполагаем, что все файлы лежат в одной директории. В начале нам требуется единожды вызвать функцию Load() для того, что бы загрузить все изображения и создать объект текстуры OpenGL. Свойствами класса являются имена файлов изображении (на данный момент записываются с полным путем) и указатель на объект текстуры OpenGL. Этот единый указатель дает доступ ко всем 6 граням кубической текстуры. Во время выполнения должен быть вызван Bind() с подходящим модулем текстуры для того, что бы сделать текстуру доступной для шейдера.

> cubemap_texture.cpp:28

    bool CubemapTexture::Load()
    {
        glGenTextures(1, &m_textureObj);
        glBindTexture(GL_TEXTURE_CUBE_MAP, m_textureObj);

        Magick::Image* pImage = NULL;
        Magick::Blob blob;

        for (unsigned int i = 0 ; i < ARRAY_SIZE_IN_ELEMENTS(types) ; i++) {
            pImage = new Magick::Image(m_fileNames[i]);

            try {
                pImage->write(&blob, "RGBA");
            }
            catch (Magick::Error& Error) {
                cout << "Error loading texture '" << m_fileNames[i] << "': " << Error.what() << endl;
                delete pImage;
                return false;
            }

            glTexImage2D(types[i], 0, GL_RGB, pImage->columns(), pImage->rows(), 0, GL_RGBA,
                GL_UNSIGNED_BYTE, blob.data());

            delete pImage;
        }

        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

        return true;
    }

Функция, которая загружает текстуру, начинается с генерации объекта текстуры. Этот объект привязывается к специальной метке GL_TEXTURE_CUBE_MAP. После этого мы попадаем в цикл, который содержит перечисление GL, которое представляет стороны кубической текстуры (GL_TEXTURE_CUBE_MAP_POSITIVE_X, GL_TEXTURE_CUBE_MAP_NEGATIVE_X и т.д). Это перечисление совпадает с вектором строк 'm_fileNames', что упрощает цикл. Файлы изображении загружаются один за другим через ImageMagick и затем указываются в OpenGL через glTexImage2D(). Заметим, что каждый вызов этой функции производится через соответствующий GL enum для этой стороны (вот почем массивы 'types' и 'm_fileNames' должны совпадать). После того, как кубическая текстура загружена и заполнена, мы устанавливаем некоторые флаги. Вы должны быть уже знакомы с ними всеми, кроме GL_TEXTURE_WRAP_R. Это перечисление просто означает использование 3-мерных координат текстуры. Для них всех мы также добавили режим сжатия.

> cubemap_texture.cpp:95

    void CubemapTexture::Bind(GLenum TextureUnit)
    {
        glActiveTexture(TextureUnit);
        glBindTexture(GL_TEXTURE_CUBE_MAP, m_textureObj);
    }

Эта функция должна быть вызвана до того, как мы будем использовать текстуру для рисования скайбокса. Привязываться текстура будет к GL_TEXTURE_CUBE_MAP, мы уже использовали это значение в функции Load().

> skybox_technique.h:25

    class SkyboxTechnique : public Technique {
    public:

        SkyboxTechnique();

        virtual bool Init();

        void SetWVP(const Matrix4f& WVP);
        void SetTextureUnit(unsigned int TextureUnit);

    private:

        GLuint m_WVPLocation;
        GLuint m_textureLocation;
    };

Для рендера скайбокса будет использоваться его собственный метод. Он имеет набор свойств, которые мы должны указать через вызовы - матрица WVP для преобразования куба или сферы и текстуру, которая будет накладываться. Давайте заглянем внутрь класса.

> skybox_technique.cpp:28

    layout (location = 0) in vec3 Position;

    uniform mat4 gWVP;

    out vec3 TexCoord0;

    void main()
    {
        vec4 WVP_Pos = gWVP * vec4(Position, 1.0);

            gl_Position = WVP_Pos.xyww;

        TexCoord0 = Position;
    }

Это вершинный шейдер для скайбокса. Он довольно прост, но вы должны обратить внимание на некоторые трюки. Первый трюк в том, что мы преобразуем входящий вектор позиции как обычно через матрицу WVP, но затем в векторе, который будет передан в фрагментный шейдер, мы заменяем координату Z на W. После того, как завершится вершинный шейдер, растеризатор получит вектор gl_Position vector и произведет деление перспективы (деление на W) для того, что бы закончить проекцию. Когда мы установим Z в W, мы гарантируем, что итоговое значения позиции Z будет равно 1.0. Это значит, что скайбокс всегда будет проигрывать тест глубины другим моделям сцены. Так скайбокс всегда будет фоном для всего, что находится на сцене, это именно то, что мы и хотели.

Второй трюк в том, что мы используем исходные позиции в локальном пространстве как 3D координаты текстуры. Это работает из-за того, что выбор сэмпла в кубической текстуре выглядит как вектор из центра в точку на кубе или сфере. Поэтому позиция точки становится координатами текстуры. Вершинный шейдер передает локальные координаты каждой вершины как координаты текстуры (8 вершин для куба и гораздо больше для сферы), а затем они будут интерполированы растеризатором для каждого пикселя. Это даст нам позицию пикселя, которую мы может использовать для сэмплинга.

> skybox_technique.cpp:44

    in vec3 TexCoord0;

    out vec4 FragColor;

    uniform samplerCube gCubemapTexture;

    void main()
    {
        FragColor = texture(gCubemapTexture, TexCoord0);
    }

Фрагментный шейдер бесконечно прост. Все, что мы делаем, это используем 'samplerCube' вместо 'sampler2D' для получения доступа к кубической текстуры.

> skybox.h:27

    class SkyBox
    {
    public:
        SkyBox(const Camera* pCamera, const PersProjInfo& p);

        ~SkyBox();

        bool Init(const string& Directory,
            const string& PosXFilename,
            const string& NegXFilename,
            const string& PosYFilename,
            const string& NegYFilename,
            const string& PosZFilename,
            const string& NegZFilename);

        void Render();

    private:
        SkyboxTechnique* m_pSkyboxTechnique;
        const Camera* m_pCamera;
        CubemapTexture* m_pCubemapTex;
        Mesh* m_pMesh;
        PersProjInfo m_persProjInfo;
    };

Класс скайбокса включает несколько различных элементов - метод, кубическая текстура и модель сферы или куба. Для упрощения его использования, этот класс включает все элементы, которые требуются для его правильного использования, внутри себя. Он единожды инициализируется в начале с директорией и именами файлов кубической текстуры и затем используется во время работы приложения через функцию Render(). Единственный вызов функции заботится обо всем. Заметим, что в дополнение к компонентам выше класс так же имеет доступ к камере и значениям для проекции перспективы (FOV, Z и разрешение экрана). Это нужно для правильного заполнения экземпляра класса конвейера Pipeline.

    void SkyBox::Render()
    {
        m_pSkyboxTechnique->Enable();

        GLint OldCullFaceMode;
        glGetIntegerv(GL_CULL_FACE_MODE, &OldCullFaceMode);
        GLint OldDepthFuncMode;
        glGetIntegerv(GL_DEPTH_FUNC, &OldDepthFuncMode);

        glCullFace(GL_FRONT);
        glDepthFunc(GL_LEQUAL);

        Pipeline p;
        p.Scale(20.0f, 20.0f, 20.0f);
        p.Rotate(0.0f, 0.0f, 0.0f);
        p.WorldPos(m_pCamera->GetPos().x, m_pCamera->GetPos().y, m_pCamera->GetPos().z);
        p.SetCamera(m_pCamera->GetPos(), m_pCamera->GetTarget(), m_pCamera->GetUp());
        p.SetPerspectiveProj(m_persProjInfo);
        m_pSkyboxTechnique->SetWVP(p.GetWVPTrans());
        m_pCubemapTex->Bind(GL_TEXTURE0);
        m_pMesh->Render();

        glCullFace(OldCullFaceMode);
        glDepthFunc(OldDepthFuncMode);
    }

Эта функция рендерит скайбокс. Мы начинаем с разрешения метода скайбокса. Затем мы встречаемся с новым API OpenGL - glGetIntegerv(). Эта функция возвращает значение состояния OpenGL для перечисления, указанного в первом параметре. Второй параметр - это адрес на массив типа int, который получит состояние (в нашем случае достаточно одного значения в массиве). Нам необходимо использовать соответствующую функцию Get* согласно типу состояния - glGetIntegerv(), glGetBooleanv(), glGetInteger64v(), glGetFloatv() и	glGetDoublev(). Причина использования здесь glGetIntegerv() в том, что мы собираемся изменить несколько основным состояний, которые мы установили в glut_backend.cpp для всех уроков. Мы хотим изменить состояния только для рендера в данной части кода, после чего устанавливаем старые значения обратно. Остальная часть программы ничего не узнает об изменениях.

Первая вещь, которую мы изменим, это режим отброса. Обычно мы отбрасываем поверхности, которые направленны противоположно камере, а в данном случае камера находится внутри коробки, поэтому мы хотим видеть их впереди, а не сзади. Проблема в том, что в общей модели сферы, которая использована здесь, треугольники направленны вне, в то время как нужно внутрь (зависит от порядка указания вершин). Мы можем или изменить модель или изменить на противоположное направление режима отброса. Мы предпочтем последний вариант, поэтому та же самая модель сферы может быть использована и в других ситуациях. Поэтому, мы говорим OpenGL отбрасывать лицевую сторону треугольников.

Вторая вещь, которую мы изменили, это функция теста глубины. По умолчанию мы говорим OpenGL, что входящий пиксель выигрывает тест глубины, если его значение Z меньше, чем уже записанное. Но в ситуации с скайбоксом значение Z всегда равно дальнему Z (подробнее об этом выше). Дальний Z вырезается функцией теста глубины, если будет установлено "меньше чем". Что бы он был частью сцены мы изменим тест глубины на "меньше либо равен".

Следующее, что делает эта функция, - это вычисление матрицы WVP. Заметим, что мировая позиция скайбокса устанавливается равной камере. Это удержит камеру ровно по центру в любой ее позиции. После того, как привязана кубическая текстура к модулю 0 (этот модуль уже был настроен в SkyboxTechnique при создании в SkyBox::Init()). Затем рендерится меш сферы. Наконец, возвращаются исходные значения отброса и теста глубины.

Полезным для производительности советом будет всегда рендерить скайбокс в последнюю очередь (после всех остальных моделей). Причина в том, что мы знаем, что он всегда будет позади других объектов сцены. Некоторые GPUs (графические процессоры) имеют механизм для оптимизации, заключающийся в том, что фрагментный шейдер не будет вызван, если пиксель проигрывает тест глубины. Это очень полезно в ситуации с скайбоксом, поскольку фрагментный шейдер будет вызван только для оставшихся фоновых пикселей, которые не покрыты другими моделями. Но для этого необходим заполненный буфер глубины, который мы получаем после рендера других моделей.
