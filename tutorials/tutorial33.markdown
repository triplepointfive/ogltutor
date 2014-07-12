---
title: Урок 33 - Дублирующий рендер (Instanced Rendering)
---

Представьте, что вы хотите рендерить сцену, в которой движется огромная армия. У вас есть модель солдата и вы хотите рендерить несколько тысяч солдат. Первый способ - в лоб - вызывать отрисовку столько раз, сколько движется солдат, изменяя только требуемые uniform-переменные. Например, каждый солдат расположен в различной точке, каждый может быть до 10% темнее / светлее чем обычный и так далее. Кроме этого мы должны обновлять матрицу WVP между вызовами отрисовки так же, как и другие переменные, которые относятся к конкретному солдату. У такой схемы будут большие расходы. Но есть способ лучше.

Рассмотрим дублирующий рендер. *Instance* - это единственное вхождение модели, которую вы хотите рендерить (в нашем случае это солдат). Дублирующий рендер означает, что мы можем рендерить несколько образцов в одном вызове отрисовки и предоставлять каждый образец с уникальными данными атрибутов. Мы рассмотрим оба способа сделать это.

В первом методе дублирования некоторые атрибуты (такие как матрица WVP) помещаются в отдельный буфер вершин. Обычно вершинный процессор делает один шаг внутри VBs для каждой вершины. В случае VBs с дублирующимися данными этот шаг происходит только после того, как все "обычные" вершины были отрисованы. VBs с дублирующимися данными просто предоставляет атрибуты, которые общие для всех вершин. Рассмотрим следующее изображение:

![](/images/t33_instance_vbs.jpg)

Что если наша модель содержит 100 вершин. Каждая вершина имеет позицию, нормаль и координаты текстуры. Кроме этого мы добавляем еще и четвертый буфер с тремя матрицами WVP. План таков: отрисовка 100 вершин, применяя первую матрицу на позицию каждой из них, затем рисовать их снова, используя вторую и, наконец, с третьей. Мы сделаем это в одном вызове вместо 3-х. Матрица WVP будет входящей переменной вершины, но так как четвертый буфер помечен как дублирующий, то матрица не будет изменяться до тех пор, пока все вершины не будут отрисованы.

Второй метод использует встроенную переменную шейдера, называемую *gl_InstanceID*, которая, что не удивительно, говорит нам текущий дублирующий индекс. Мы можем использовать этот индекс для поиска конкретные данные в массиве uniform-переменной.

## [Прямиком к коду!](https://github.com/triplepointfive/ogldev/tree/master/tutorial33)

> mesh.h:50

    class Mesh
    {
    public:
        ...
        void Render(unsigned int NumInstances, const Matrix4f* WVPMats, const Matrix4f* WorldMats); 
        ...
    private:
        ...
        #define INDEX_BUFFER 0    
        #define POS_VB       1
        #define NORMAL_VB    2
        #define TEXCOORD_VB  3    

            #define WVP_MAT_VB   4
            #define WORLD_MAT_VB 5

        GLuint m_VAO;

            GLuint m_Buffers[6];
    ...

Это изменения в классе меша. Функция Render() теперь принимает 2 массива, которые содержат матрицы WVP и мировую для всех образцов и NumInstances - количество матриц в каждом массиве. Мы так же добавили 2 VBs для их хранения.

> mesh.cpp:91

    bool Mesh::InitFromScene(const aiScene* pScene, const string& Filename)
    {
        ...
        // Generate and populate the buffers with vertex attributes and the indices
        glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[POS_VB]);
        glBufferData(GL_ARRAY_BUFFER, sizeof(Positions[0]) * Positions.size(), &Positions[0], GL_STATIC_DRAW);
        glEnableVertexAttribArray(POSITION_LOCATION);
        glVertexAttribPointer(POSITION_LOCATION, 3, GL_FLOAT, GL_FALSE, 0, 0);

        glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[TEXCOORD_VB]);
        glBufferData(GL_ARRAY_BUFFER, sizeof(TexCoords[0]) * TexCoords.size(), &TexCoords[0], GL_STATIC_DRAW);
        glEnableVertexAttribArray(TEX_COORD_LOCATION);
        glVertexAttribPointer(TEX_COORD_LOCATION, 2, GL_FLOAT, GL_FALSE, 0, 0);

        glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[NORMAL_VB]);
        glBufferData(GL_ARRAY_BUFFER, sizeof(Normals[0]) * Normals.size(), &Normals[0], GL_STATIC_DRAW);
        glEnableVertexAttribArray(NORMAL_LOCATION);
        glVertexAttribPointer(NORMAL_LOCATION, 3, GL_FLOAT, GL_FALSE, 0, 0);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_Buffers[INDEX_BUFFER]);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices[0]) * Indices.size(), &Indices[0], GL_STATIC_DRAW);

        glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[WVP_MAT_VB]);

        for (unsigned int i = 0; i < 4 ; i++) {
            glEnableVertexAttribArray(WVP_LOCATION + i);
            glVertexAttribPointer(WVP_LOCATION + i, 4, GL_FLOAT, GL_FALSE, sizeof(Matrix4f), (const GLvoid*)(sizeof(GLfloat) * i * 4));
            glVertexAttribDivisor(WVP_LOCATION + i, 1);
        }

        glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[WORLD_MAT_VB]);

        for (unsigned int i = 0; i < 4 ; i++) {
            glEnableVertexAttribArray(WORLD_LOCATION + i);
            glVertexAttribPointer(WORLD_LOCATION + i, 4, GL_FLOAT, GL_FALSE, sizeof(Matrix4f), (const GLvoid*)(sizeof(GLfloat) * i * 4));
            glVertexAttribDivisor(WORLD_LOCATION + i, 1);
        }

        return GLCheckError();
    }

Код выше создает и заполняет различные VBs меша данными вершин. Была добавлена выделенная жирным часть, которая показывает, как заставить VBs хранить дублирующиеся данные. Мы начинаем, как обычно, с привязывания буфера матриц WVP. Так как матрица WVP - 4x4 и мы планируем передавать ее как входящую переменную в VS, то мы не можем использовать только один вершинный атрибут для нее, поскольку вершинные атрибуты могут содержать не более 4-х вещественных и целых чисел. Поэтому у нас используется цикл, который включает и настраивает 4 последовательных вершинных атрибута. Каждый атрибут будет содержать один вектор из матрицы. Затем мы настраиваем атрибуты. Каждый из 4-х состоит из 4-ки вещественных чисел, и расстояние между атрибутами соседних матриц равно размеру матрицы 4x4. Кроме того, мы не хотим, что бы OpenGL нормировал входящие данные. Это объяснения для 2-5 параметров glVertexAttribPointer(). Последний параметр - смещение атрибута внутри экземпляра данных. Первый вектор имеет смещение 0, второй - 16 и т.д.

Функция glVertexAttribDivisor() задает экземпляр данных, а не данные вершин. Она принимает 2 параметра: первый - атрибут вершины, а второй говорит OpenGL скорость, с которой будут изменяться данные для образцов. В общем это означает сколько раз весь набор вершин рендерится до обновления атрибутов из буфера. По-умолчанию делитель равен 0. Это приводит к регулярному обновлению от вершины к вершине. Если делитель равен 10, то первые 10 образцов будут использовать первый кусок данных из буфера, следующие 10 второй и т.д. Мы хотим предназначить матрицу WVP для каждого образца, поэтому устанавливаем делитель в 1.

Мы повторяем эти шаги для всех 4 массивов вершинных атрибутов матрицы. Затем мы делаем то же самое для мировой матрицы. Заметим, что в отличие от других вершинных атрибутов, таких как позиция и нормали, мы не загружаем каких-либо данных в буферы. Причина в том, что матрицы мировая и WVP - динамические, и будут обновляться каждый кадр. Поэтому мы только устанавливаем настройки на будущее и оставляем буферы без инициализации.

> mesh.cpp:253

    void Mesh::Render(unsigned int NumInstances, const Matrix4f* WVPMats, const Matrix4f* WorldMats)
    {
            glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[WVP_MAT_VB]);
            glBufferData(GL_ARRAY_BUFFER, sizeof(Matrix4f) * NumInstances, WVPMats, GL_DYNAMIC_DRAW);

            glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[WORLD_MAT_VB]);
            glBufferData(GL_ARRAY_BUFFER, sizeof(Matrix4f) * NumInstances, WorldMats, GL_DYNAMIC_DRAW);

        glBindVertexArray(m_VAO);

        for (unsigned int i = 0 ; i < m_Entries.size() ; i++) {
            const unsigned int MaterialIndex = m_Entries[i].MaterialIndex;

            assert(MaterialIndex < m_Textures.size());

            if (m_Textures[MaterialIndex]) {
                m_Textures[MaterialIndex]->Bind(GL_TEXTURE0);
            }

            glDrawElementsInstancedBaseVertex(GL_TRIANGLES,
                m_Entries[i].NumIndices,
                GL_UNSIGNED_INT, 
                (void*)(sizeof(unsigned int) * 
                m_Entries[i].BaseIndex), 
                NumInstances,
                m_Entries[i].BaseVertex);
        }

        // Убедимся, что VAO не изменится из вне
        glBindVertexArray(0);
    }

Это обновленная функция Render() класса Mesh. Она теперь принимает 2 массива матриц - матрицы WVP и мировых преобразований (NumInstances - это размер обоих массивов). До привязывания нашего VAO (подробнее об этом в предыдущем уроке) мы привязываем и загружаем матрицы в соответствующие им буферы вершин. Мы вызываем glDrawElements**Instanced**BaseVertex вместо glDrawElementsBaseVertex. Единственное изменение в этой функции в том, что она принимает количество образцов пятым параметром. Это означает, что одинаковые индексы (согласно другим параметрам) будут отрисовываться опять и опять - всего NumInstances раз. OpenGL будет получать данные для каждой вершины из VBs, чей делитель равен 0 (по старому). Он будет получать новые данные из VBs, чей делитель - 1 только после того, как весь образец будет отрисован. Общий алгоритм этого вызова таков:

- for (i = 0 ; i < NumInstances ; i++)
    - if (i mod divisor == 0)
        - получаем атрибут i/divisor из VBs с дублирующимися данными
    - for (j = 0 ; j < NumVertices ; j++)
        - получаем атрибут j из VBs с данными вершин

<!-- well hey there sailor -->
> lightning_technique.cpp:25

    #version 410

    layout (location = 0) in vec3 Position;
    layout (location = 1) in vec2 TexCoord;
    layout (location = 2) in vec3 Normal;

        layout (location = 3) in mat4 WVP;
        layout (location = 7) in mat4 World;

    out vec2 TexCoord0;
    out vec3 Normal0;
    out vec3 WorldPos0;

        flat out int InstanceID;

    void main()
    {
        gl_Position = WVP * vec4(Position, 1.0);
        TexCoord0   = TexCoord;
        Normal0     = World * vec4(Normal, 0.0)).xyz;
        WorldPos0   = World * vec4(Position, 1.0)).xyz;
        
            InstanceID = gl_InstanceID;
    };

Это новый VS. Вместо получения WVP и мировой матриц как uniform-переменных, они теперь приходят как обычные вершинные атрибуты. VS не волнует, что значения будут обновляться только один раз за образец. Как объяснено выше, матрица WVP занимает позиции, а мировая матрица 7-10.

В последней строке вершинного буфера мы видим второй способ реализации дублирующего рендера (первый заключен в том, что бы передавать данные как вершинные атрибуты). 'gl_InstanceID' - встроенная переменная, которая доступна только в VS. Так как мы планируем использовать ее в FS, то мы получаем ее здесь и передаем дальше как выходящую переменную. Тип gl_InstanceID - int, поэтому и выходящая переменная целочисленная. Так как целые числа не могут быть интерполированы растеризатором, то мы помечаем ее как 'flat' (если этого не сделать, то получим ошибку компиляции). Следует заметить, что gl_InstanceID доступна только в OpenGL 4.1 и выше. Если у вас старая видеокарта, то возможно вы не сможете использовать ее.

    flat in int InstanceID;
    ...
    uniform vec4 gColor[4];

    ...

    void main()
    {
        vec3 Normal = normalize(Normal0);  
        vec4 TotalLight = CalcDirectionalLight(Normal);

        for (int i = 0 ; i < gNumPointLights ; i++) {   
            TotalLight += CalcPointLight(gPointLights[i], Normal);  
        }

        for (int i = 0 ; i < gNumSpotLights ; i++) {
            TotalLight += CalcSpotLight(gSpotLights[i], Normal);
        }

        FragColor = texture(gColorMap, TexCoord0.xy) * TotalLight * gColor[InstanceID % 4];
    };

Чтобы продемонстрировать использование gl_InstanceID я добавил uniform-массив из 4 вещественных векторов в FS. FS получает ID образца из VS и использует остаток от деления как индекс в массиве. Цвет, который был вычислен по формулам света умножается на один из цветов из массива. Помещая различные цвета в массив мы сможем получить интересную расцветку образцов.

> main.cpp:137

    Pipeline p;
    p.SetCamera(m_pGameCamera->GetPos(), m_pGameCamera->GetTarget(), m_pGameCamera->GetUp());
    p.SetPerspectiveProj(m_persProjInfo);
    p.Rotate(0.0f, 90.0f, 0.0f);
    p.Scale(0.005f, 0.005f, 0.005f);

    Matrix4f WVPMatrics[NUM_INSTANCES];
    Matrix4f WorldMatrices[NUM_INSTANCES];

    for (unsigned int i = 0 ; i < NUM_INSTANCES ; i++) {
        Vector3f Pos(m_positions[i]);
        Pos.y += sinf(m_scale) * m_velocity[i];
        p.WorldPos(Pos);

            WVPMatrics[i] = p.GetWVPTrans().Transpose();
            WorldMatrices[i] = p.GetWorldTrans().Transpose();
    }

    m_pMesh->Render(NUM_INSTANCES, WVPMatrics, WorldMatrices);

Код выше взят из главной функции рендера и показывает как вызвать обновленную функцию Mesh::Render(). Мы создаем объект конвейера и заполняем его. Все, что изменяется от образца к образцу - мировая позиция, которую мы оставляем до цикла. Мы подготавливаем 2 массива для матриц мировых и WVP. Затем в цикле мы пробегаем по всем образцам и получаем их начальную позицию из массива m_positions (который был инициализирован случайными числами при запуске). Мы вычисляем текущую позицию и устанавливаем ее в объекте конвейера. Мы можем теперь получить матрицы WVP и мировую из объекта конвейера, а затем поместить в соответствующий слот массива. Но прежде чем это сделать, мы сделаем кое-что действительно важное, что может вызвать головную боль у новичков. Мы должны транспонировать матрицы.

Дело в том, что наш класс матрицы хранит свои 16 вещественных чисел как единый вектор в памяти. Мы начинаем с верхней левой обычной матрицы и движемся вправо. Когда мы достигнем конца, мы перейдем на следующую строку. Поэтому обычно мы проходит от строки к строке, пока не достигнем нижнего правого угла. Можно сказать, что у нас 4 строки, идущие друг за другом. Каждая из этих строк окажутся вершинными атрибутами (верхняя строка будет в 3-й позиции, вторая в 4-й и т.д, согласно тому, как мы назначили в VS). Со стороны шейдера мы объявили матрицы WVP и мировую как 'mat4'. В случае, когда матрицы mat4 инициализированы через векторные атрибуты,  <u>каждый вершинный атрибут собирается как столбово-ориентированная матрица</u>. Например, в случае нашей матрицы WVP OpenGL молча вызывает конструктор mat4 как: mat4 WVP(атрибут 3, атрибут 4, атрибут 5, атрибут 6). Атрибут 3 станет первым столбцом слева, атрибут 4 вторым и т.д. Фактически это транспонирует нашу матрицу, поскольку каждая строка станет столбцом. Для избежания этого эффекта и сохранения нашей матрицы без изменений, мы транспонируем ее до загрузки в массив (жирный код выше).

### Заметка:

Если вы компилируете и запустите демо к этому уроку, то заметите счетчик FPS (кадры в секунду) в нижнем левом углу окна. OpenGL не имеет стандартных библиотек для рендера текста, поэтому разные люди используют различные методы. Я недавно открыл [freetype-gl](http://code.google.com/p/freetype-gl/) от Nicolas Rougier, и мне она понравилась. Код находится под свободной лицензией BSD. Я немного изменил исходный код, что бы было проще ее использовать, и включил его как часть демо, поэтому ничего устанавливать не требуется. Если вам интересно, как она используется, обратите внимание на 'FontRenderer' в main.cpp.