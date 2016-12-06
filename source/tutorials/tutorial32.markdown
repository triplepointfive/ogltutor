---
title: Урок 32 - Vertex Array Objects
date: 2016-12-06 16:24:30 +0300
---

Vertex Array Object (или VAO) - специальный тип объектов, который инкапсулирует все данные, связанные с вершинным процессором. Вместо хранения текущих данных они содержат ссылки на вершинный буфер, буфер индексов и указания для слоев самих вершин. Преимущество в том, что единожды настроив VAO для меша вы можете привести внутренние состояния меша просто привязав VAO. После вы сможете рендерить объект меша, при этом не придется беспокоиться об все его состояниях. VAO запомнит их для вас. Если вашему приложению требуется работать с мешами, чьи слои вершин слегка отличаются друг от друга, то VAO позаботится и об этом тоже. Достаточно убедиться, что слои были правильно настроены при создании VAO, и можно забыть про них. Теперь они "приклеены" к VAO и активируются, когда используется VAO.

При правильном использовании VAOs могут предоставить возможность оптимизации драйвера GPU. Если VAO единожды установлен и использован несколько раз, то драйвер может получить преимущества, зная отображение между буфером индексов и вершинным буфером также, как и вершинные слои в буфере. Очевидно, это зависит от конкретного драйвера, который вы используете, и это не гарантирует, что все драйверы будут действовать аналогично. В любом случае лучше запомнить, что стоит настроить VAO один раз и затем использовать его снова и снова.

В этом уроке мы собираемся обновить класс Mesh и основать его на VAO. Кроме того, мы организуем данные вершин в буферах так, как это делается в методе, известном как SOA (Structure Of Arrays). До этого момента наши вершины были представлены как структура атрибутов (позиции и прочее), а буфер вершин содержал структуры по порядку, одну за другой. Это называется AOS (Array Of Structure). SOA просто транспонирует эту схему. Вместо массива структур атрибутов мы имеем одну структуру, которая содержит несколько массивов. Каждый массив содержит только один атрибут. Для того, что бы настроить вершину GPU использует один и тот же индекс для чтения одного атрибута из каждого массива. Этот метод может быть временами более подходящим для некоторых файлов 3D формата, и интересно увидеть разные способы достижения одной и той же цели.

Следующее изображение иллюстрирует AOS и SOA:

![](/images/t32_aos_soa.jpg)

## [Прямиком к коду!](https://github.com/triplepointfive/ogldev/tree/master/tutorial32)

> mesh.h:50

    class Mesh{
    public:
        Mesh();
        ~Mesh();

        bool LoadMesh(const std::string& Filename);
        void Render();

    private:
        bool InitFromScene(const aiScene* pScene, const std::string& Filename);


            void InitMesh(const aiMesh* paiMesh,
                                std::vector<vector3f>& Positions,
                                std::vector<vector3f>& Normals,
                                std::vector<vector2f>& TexCoords,
                                std::vector<unsigned int="">& Indices);


        bool InitMaterials(const aiScene* pScene, const std::string& Filename);
        void Clear();

    #define INVALID_MATERIAL 0xFFFFFFFF

        #define INDEX_BUFFER 0

    #define POS_VB 1
    #define NORMAL_VB2
    #define TEXCOORD_VB3

        GLuint m_VAO;
        GLuint m_Buffers[4];

        struct MeshEntry{
            MeshEntry(){
                NumIndices = 0;
                BaseVertex = 0;
                BaseIndex = 0;
                MaterialIndex = INVALID_MATERIAL;
            }

            unsigned int BaseVertex;
            unsigned int BaseIndex;
            unsigned int NumIndices;
            unsigned int MaterialIndex;
        };

        std::vector<meshentry> m_Entries;
        std::vector<texture*> m_Textures;
    };

Все изменения в этом уроке инкапсулированы в классе меша, чье объявление представлено выше. Мы переключились от массивов VB / IB элементов к 4 буферам - буферы индексов, позиции, нормалей и координат текстур. Кроме этого, класс меша получил новый член, названный m_VAO, который содержит объект массива вершин. Так как наша модель может состоять из нескольких субкомпонентов, каждый со своей текстурой, то у нас есть вектор, названый m_Entries, который содержит индексы материалов так же, как и позицию субкомпонентов. NumIndices - это количество индексов в субкомпоненте, BaseVertex - это позиция, с которой начинается субкомпонент в вершинном буфере и BaseIndex - это где субкомпонент начинается внутри буфера индексов (поскольку все субкомпоненты записаны один за другим внутри одного буфера). Перед рендером субкомпонента меша нам требуется привязать его текстуру и затем отправить команду отрисовки для субкомпонента вершины. Позже мы увидим как это сделать.

> mesh.cpp:56

    bool Mesh::LoadMesh(const string& Filename){
        // Удаляем предыдущую загруженную модель (если есть)
        Clear();

        // Создание VAO
        glGenVertexArrays(1, &m_VAO);
        glBindVertexArray(m_VAO);

        // Создание буферов для атрибутов вершин
        glGenBuffers(ARRAY_SIZE_IN_ELEMENTS(m_Buffers), m_Buffers);

        bool Ret = false;
        Assimp::Importer Importer;

        const aiScene* pScene = Importer.ReadFile(Filename.c_str(), aiProcess_Triangulate | aiProcess_GenSmoothNormals | aiProcess_FlipUVs);

        if (pScene){
            Ret = InitFromScene(pScene, Filename);
        }else{
            printf("Error parsing '%s': '%s'\n", Filename.c_str(), Importer.GetErrorString());
        }

        // Удостоверимся, что VAO не изменится из внешнего кода
        glBindVertexArray(0);

        return Ret;
    }

В главной функции загрузки меша не так уж и много изменений. Мы создаем VAO через glGenVertexArrays() предоставляя ему число элементов в массиве GLuint, и адрес самого массива (в нашем случае требуется один GLuint). После этого мы привязываем VAO через glBindVertexArray(). Одновременно может быть привязан только один VAO. Теперь все изменения состояния вершинного процессора будут задаваться этим VAO. 4 буфера создаются через использование glGenBuffers(), и меш загружается через Open Asset Import Library (об этом ниже). Очень важна функция glBindVertexArray(0) в конце этой функции. Привязав 0 мы гарантируем, что не произойдет никаких изменений в вершинном процессоре, затрагивающих наш VAO (OpenGL никогда не создаст VAO со значением 0, так что это безопасно).

> mesh.cpp:86

    bool Mesh::InitFromScene(const aiScene* pScene, const string& Filename){
        m_Entries.resize(pScene->mNumMeshes);
        m_Textures.resize(pScene->mNumMaterials);

        // Подготавливаем вектора для вершинных атрибутов и индексов
        vector<vector3f> Positions;
        vector<vector3f> Normals;
        vector<vector2f> TexCoords;
        vector<unsigned int=""> Indices;

        unsigned int NumVertices = 0;
        unsigned int NumIndices = 0;

        // Подсчитываем количество вершин и индексов
        for (unsigned int i = 0 ; i < m_Entries.size() ; i++){
            m_Entries[i].MaterialIndex = pScene->mMeshes[i]->mMaterialIndex;
            m_Entries[i].NumIndices = pScene->mMeshes[i]->mNumFaces * 3;
            m_Entries[i].BaseVertex = NumVertices;
            m_Entries[i].BaseIndex = NumIndices;

            NumVertices += pScene->mMeshes[i]->mNumVertices;
            NumIndices+= m_Entries[i].BaseIndex;
        }

        // Резервируем пространство в векторах для атрибутов вершин и индексов
        Positions.reserve(NumVertices);
        Normals.reserve(NumVertices);
        TexCoords.reserve(NumVertices);
        Indices.reserve(NumIndices);

        // Инициализируем меши в сцене один за другим
        for (unsigned int i = 0 ; i < m_Entries.size() ; i++){
            const aiMesh* paiMesh = pScene->mMeshes[i];
            InitMesh(paiMesh, Positions, Normals, TexCoords, Indices);
        }

        if (!InitMaterials(pScene, Filename)) {
            return false;
        }

        // Создаем и заполняем буферы с вершинными атрибутами и индексами
        glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[POS_VB]);
        glBufferData(GL_ARRAY_BUFFER, sizeof(Positions[0]) * Positions.size(), &Positions[0], GL_STATIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);

        glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[TEXCOORD_VB]);
        glBufferData(GL_ARRAY_BUFFER, sizeof(TexCoords[0]) * TexCoords.size(), &TexCoords[0], GL_STATIC_DRAW);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, 0);

        glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[NORMAL_VB]);
        glBufferData(GL_ARRAY_BUFFER, sizeof(Normals[0]) * Normals.size(), &Normals[0], GL_STATIC_DRAW);
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 0, 0);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_Buffers[INDEX_BUFFER]);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices[0]) * Indices.size(), &Indices[0], GL_STATIC_DRAW);

        return true;
    }

Это следующий уровень детализации в плане загрузки меша. Open Asset Import Library (Assimp) загружает данные меша в структуру aiScene, и мы получаем указатель на нее. Теперь нам требуется загрузить их в буфер GL и привязать к VAO. Мы делаем это с помощью STL вектора. У нас есть по одному вектору на буфер. Мы подсчитываем количество вершин и индексов в структуре aiScene и для каждой структуры aiMesh мы записываем ее индекс материала, количество индексов, вершины и индексы в массив m_Entries. Мы так же резервируем пространство в векторах соответственно. Затем мы проходим через каждую структуру aiMesh внутри aiScene и инициализируем их.  Вектора передаются по ссылке в InitMesh(), что позволяет заполнять их как обычно. Материалы инициализируются так же, как и раньше.

В последней части функции все самое интересное. Буферы позиции, нормалей и координат текстуры привязываются один за другим к метке GL_ARRAY_BUFFER target. Все дальнейшие операции на эту метку будут влиять только на текущие привязанные буферы, и изменения вернутся, когда этот же буфер снова будет привязан к этой же метке. Для каждого из 3 буферов мы:

1. Заполнить буфер данными через glBufferData().
2. Включить соответствующий вершинный атрибут через glEnableVertexAttribArray().
3. Настроить вершинный атрибут (номер компоненты, ее тип и прочее) через glVertexAttribPointer().

Буфер индексов инициализируется через привязывание к метке GL_ELEMENT_ARRAY_BUFFER. Нам только требуется заполнить его индексами и все. Буфер теперь инициализирован и мы все это инкапсулировали в VAO.

> mesh.cpp:148

    void Mesh::InitMesh(const aiMesh* paiMesh,
            vector<vector3f>& Positions,
            vector<vector3f>& Normals,
            vector<vector2f>& TexCoords,
            vector<unsigned int="">& Indices){
        const aiVector3D Zero3D(0.0f, 0.0f, 0.0f);

        // Заполняем векторы вершинных атрибутов
        for (unsigned int i = 0 ; i < paiMesh->mNumVertices ; i++) {
            const aiVector3D* pPos= &(paiMesh->mVertices[i]);
            const aiVector3D* pNormal = &(paiMesh->mNormals[i]);
            const aiVector3D* pTexCoord = paiMesh->HasTextureCoords(0) ? &(paiMesh->mTextureCoords[0][i]) : &Zero3D;

            Positions.push_back(Vector3f(pPos->x, pPos->y, pPos->z));
            Normals.push_back(Vector3f(pNormal->x, pNormal->y, pNormal->z));
            TexCoords.push_back(Vector2f(pTexCoord->x, pTexCoord->y));
        }

        // Заполняем буфер индексов
        for (unsigned int i = 0 ; i < paiMesh->mNumFaces ; i++) {
            const aiFace& Face = paiMesh->mFaces[i];
            assert(Face.mNumIndices == 3);
            Indices.push_back(Face.mIndices[0]);
            Indices.push_back(Face.mIndices[1]);
            Indices.push_back(Face.mIndices[2]);
        }
    }

Эта функция отвечает за загрузку каждой структуры aiMesh, которую содержит aiScene. Заметим как вектора передаются по ссылке и обращение через функцию push_back() класса вектор STL.

> mesh.cpp:225

    void Mesh::Render()
    {
        glBindVertexArray(m_VAO);

        for (unsigned int i = 0 ; i < m_Entries.size() ; i++) {
          const unsigned int MaterialIndex = m_Entries[i].MaterialIndex;

          assert(MaterialIndex < m_Textures.size());

          if (m_Textures[MaterialIndex]){
                  m_Textures[MaterialIndex]->Bind(GL_TEXTURE0);
          }

          glDrawElementsBaseVertex(GL_TRIANGLES,
                                  m_Entries[i].NumIndices,
                                  GL_UNSIGNED_INT,
                                  (void*)(sizeof(unsigned int) * m_Entries[i].BaseIndex),
                                  m_Entries[i].BaseVertex);
        }

        // Make sure the VAO is not changed from the outside
        glBindVertexArray(0);
    }

Наконец, мы дошли и до функции рендера. Мы начинаем с привязывания нашего VAO и... это все, что нам требуется для настройки состояния вершинного процессора! Так как состояния уже здесь, то при привязывании они изменяются на те, что были установлены при инициализации VAO. Теперь нам требуется рисовать субкомпоненты меша и привязывать соответствующую текстуру перед каждым. Для этого мы используем информацию в массиве m_Entries array, и новая функция отрисовки называется glDrawElementsBaseVertex(). Эта функция принимает топологию, число индексов и их тип. Четвертый параметр говорит, откуда начинать в буфере индекса. Проблема в том, что индексы, которые поставляет Assimp для каждого меша начинаются с 0, и мы накапливаем их в один буфер. Поэтому теперь нам требуется сообщить функции отрисовки смещение в байтах в буфере, откуда начинаются индексы субкомпонента. Мы делаем это через умножение базового индекса текущего входа на размер индекса. Так как вершинные атрибуты так же накапливаются в их собственный буфер, то мы аналогично поступаем с пятым параметром - базовой вершиной. Обратите внимание, что мы предоставляем ее как индекс, а не как смещение в байта, потому что может быть несколько буферов вершин с различными типами атрибутов (и, следовательно, различной длины). OpenGL будет нужно умножить базовую вершину на шаг каждого буфера, чтобы получить смещение этого буфера. Ни о чем не нужно беспокоиться.

Перед выходом мы обнулим текущий VAO, причина все та же, что и при создании - мы не хотим, что бы VAO можно было изменить все класса меш.

> mesh.cpp:50

    glDeleteVertexArrays(1, &m_VAO);

Функция выше удаляет VAO. Она не удаляет буферы, которые привязаны к нему (они могут относиться к нескольким VAOs одновременно).
