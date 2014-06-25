---
title: Урок 38 - Скелетная анимация с Assimp
---
<a href="http://ogldev.atspace.co.uk/www/tutorial38/tutorial38.html"><h2>Теоретическое введение</h2></a>

<p>
    Итак, вот это. То, о чем миллионы моих читателей (ну хорошо, хорошо, я немного приувеличиваю ;-)) давно уже просят.
    <i>Скелетная анимация (Skeletal animation)</i>, известная так же как <i>Скининг (Skinning)</i>, с библиотекой Assimp.
</p>
<p>
    Скелетная анимация состоит из 2 частей. Первую выполняет 3d артист, а вторую вы, программист (или скорее движек,
    который вы пишите). Первая часть создается в ПО для моделирования и называется <i>Риггинг (Rigging)</i>. В этом
    этапе моделер создает скелет из костей внутри меша. Меш в данном случае служит кожей объекта (будь это человек,
    монстр или кто-то еще), а кости будут использоваться для движения меша таким образом, что бы происходила имитация
    движения в реальном мире. Для этого каждая вершина привязывается к одной или более костей. Когда вершина
    присоединена устанавливается вес, который задает силу влияния кости на вершину. Хорошей практикой является установка
    суммарного веса для вершины равным 1. Например, если вершина расположена между 2 костями, то вероятно мы захотим
    разделить вес по 0.5 между костьми, потому, что мы ожидаем одинакового воздействия на вершину. Хотя, если вершина
    полностью во влиянии 1 кости, то вес будет равен 1 (что означает полный контроль над движением вершины).
</p>
<p>
    Вот пример скелета, созданного в blender:
</p>
<img src="/images/t38_rigging.jpg"/>
<p>
    То, что мы видем выше - важная часть анимации. Артист риггит скелет и определяет ключевые кадры для каждого
    типа анимации ("ходьба", "бег", "смерть" и т.д.). Ключевые кадры хранят преобразования всех костей в важных позициях
    по ходу анимации. Графический движек интерполирует между позициями в кадрах и создает плавное движение между ними.
</p>
<p>
    Часто используется иерархическая структура костей для скелетной анимации. Это значит, что кости имеют потомков /
    родителей тем самым создавая дерево костей. Каждая кость имеет родителя, кроме корневой кости. В случае, например,
    человеческого тела хорошим выбором будет позвоничник, у которого дети ноги и плечи, а пальцы еще на уровень ниже.
    Когда движется родительская кость, то движутся и потомки, но если движется потомок, то на родителя это не влияет
    (мы можем двигать пальцами свободно от длани, но при движении руки пальцы следуют за ней). С практической точки
    зрения это значит, что когда мы хотим переместить кость, то нам требуется скомбинировать преобразования и для
    всех родительских костей, которые ведут от корневой кости.
</p>
<p>
    К теме риггинга мы больше не вернемся. Это сложная область и она не связанна с программированием графики. ПО для
    моделирования имеет продвинутые инструметы для помощи артистам в их работе; для создания красивого меша и скелета
    нужно иметь хорошие навыки. Давайте рассмотрим, что требуется графическому движку для создания скелетной анимации.
</p>
<p>
    Для начала увеличим вершинный буфер с информацией о костях для каждой вершины. Нам доступно несколько опций, но мы
    сделаем "в лоб". Для каждой вершины мы собираемся добавить массив слотов, где каждый слот - id кости и ее вес. Для
    упрощения мы будем использовать только 4 слота, тем самым ограничив число костей на вершину. Если вы хотите
    использовать больше, то можете увеличить размер массива, но для модели из Doom 3, приложенной к этому уроку, 4-х
    костей достаточно. Теперь обновленная струстура вершины имеет вид:
</p>
<img src="/images/t38_vertex.jpg" />
<p>
    Id костей являются индексами в массиве преобразований для костей. Эти преобразования будут применены на позицию и
    нормаль до матрицы WVP (т.е. они преобразовывают вершину из "пространства костей" в локальное пространство). Вес
    будет использован для комбинации преобразований нескольких костей в единое преобрзование и итоговый вес обязан быть
    равным 1 (ответственность несет ПО для моделирования). Обычно мы будем интерполировать между ключевыми кадрами
    анимации и обновлять массив преобразований костей каждый кадр.
</p>
<p>
    Способ, которым создается массив преобразований для костей хитро устроен. Преобразования - набор в иерархической
    структуре (попросту дерево) и хорошей практикой считается хранить вектор масштабирования, кватернион вращения и
    вектор смещения в каждом листе дерева. Фактически, каждый лист - массив 3-х элеметов. Каждая запись в массиве должна
    иметь временное обозначение. Случай, когда время в приложении будет совпадать с этим временем крайне маловероятен,
    поэтому наш код должен интерполировать масштабирование / вращение / смещение для получения правильного
    преобразования точки во времени. Этот процесс будет происходить для каждого листа от текущей кости к корневой и
    перемножать цепочку преобразований для получения итогового результата. Мы сделаем это для всех костей и обновим
    шейдер.
</p>
<p>
    Все, что мы обсудили ранее несло общий характер. Но этот урок посвящен скелетной анимации <b>с Assimp</b>, поэтому
    мы должны снова погружиться в библиотеку и увидить, как происходит скиннинг в ней. Хорошая черта Assimp в том, что
    он поддерживает загрузку данных о костях в нескольких форматах. Плохая часть в том, что вам по-прежнему придется
    сделать немного работы для генерации преобразований костей, которые понадобятся в шейдерах.
</p>
<p>
    Давайте начнем с информации о костях на уровне вершин. Вот соответсвующая часть структуры данных Assimp:
</p>
<img src="/images/t38_assimp1.jpg">
<p>
    Как вы, наверное, помните из урока по Assimp, всё содержится в объекте класса aiScene (который создается при импорте
    файла меша). aiScene хранит массив объектов aiMesh. aiMesh - часть модели, в которой находятся данные вершин, такие
    как позиция, нормаль, координаты текстуры и прочее. Теперь мы видим, что aiMesh также содержит массив объектов
    aiBone. Не удивительно, что там хранятся данные об одной кости в скелете меша. Каждая кость имеет имя, по которому
    ее можно найти в иерархии костей, массив веса вершин и матрицу смещения 4x4. Причина, по которой нам нужна эта
    матрица - вершины заданы в локальном пространстве. Это значит, что даже без поддержки скелетной анимации наш код
    может загрузить и рендерить модель. Но преобразования костей в иерархии задаются в пространтсве костей (и для каждой
    кости свое пространство, вот почему нам требуется перемножать преобразования). Итого, задача матрицы смещения в
    перемещении вершин из локального пространства в пространство конкретной кости.
</p>
<p>
    С массивом веса вершин все интереснее. Каждая запись в этом массиве содержит индекс в массиве вершин в aiMesh
    (вспомним, что вершина распологается в несколькиз массивах одинаковой длины) и вес. Сумма всех весов вершины должна
    быть равна 1, но что бы найти ее потребуется пройтись по всем костям и сложить в некий список для каждой вершины.
</p>
<p>
    После того, как мы собрали информацию о костях на уровне вершин нам требуется обработать преобразования
    иерархии костей для создания итогового преобразования, которое будет загружено в шейдер. Следующее изображение
    покажет подходящую структуру данных:
</p>
<img src="/images/t38_assimp2.jpg">
<p>
    Мы снова начинаем с aiScene. Объект aiScene хранит указатель на объект класса aiNode, который является корнем
    иерархии (или дерева). Каждый лист в дереве имеет указатель на родителя и массив указателей на потомков. Это
    позволяет нам удобно переходить по дереву вверх и вниз. Кроме того, лист хранит матрицу преобразований, которое
    переводит из пространства листа в пространство родителя. И наконец, у листа может быть или не быть имени. Если лист
    соответсвует кости, то их имена должны совпадать. Но временами лист не имеет имени (это значит, что нет подходящей
    кости) и его задача в помощи моделеру разбить модель и добавить на пути промежуточные преобразования.
</p>
<p>
    Последний кусок мозайки - массив aiAnimation, который записан в объекте aiScene. Один объект aiAnimation
    представляет собой набор кадров анимации, такой как "ходьба", "бег", "выстрел" и прочие. Интерполируя между этими
    кадрами мы получаем вожделенный эффект, соответсвующий названию метода анимации. Анимация имеет продолжительность в 
    тиках (ticks) и задает число тиков в секунду (т.е. 100 тиков со скоростью 25 тиков в секунду - 4 секунды анимации),
    это помогает задавать скорость анимации т.о., что бы она выглядила одинаково на любом железе. Кроме того, анимация 
    имеет массив объектов aiNodeAnim, называемых каналами. Каждый канал фактически кость с ее преобразованиями. Канал 
    хранит имя, которое должно соответствовать названию одной из костей в иерархии и дереве массивов преобразований.
</p>
<p>
    Для вычисления итогового преобразования костей с точки зрения времени, нам требуется найти 2 записи в каждом из этих
    массивов, которые соответсвуют времени и интерполировать значения между ними. Нам требуется скомбинировать
    преобразования в одну матрицу. Сделав это мы находим соответствующую кость в иерархии и переходим к родителю. Затем 
    находим подходящий канал для родителя и повторяем процесс интерполяции. Мы перемножаем 2 матрицы вместе и продолжаем
    пока не достигнем корневого элемента.
</p>

<a href="https://github.com/triplepointfive/ogldev/tree/master/tutorial38"><h2>Прямиком к коду!</h2></a>

</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">mesh.cpp:77</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>bool Mesh::LoadMesh(const string&amp; Filename)
{
    // Очищаем данные прошлого меша (если был загружен)
    Clear();

    // Создаем VAO
    glGenVertexArrays(1, &amp;m_VAO);
    glBindVertexArray(m_VAO);

    // Создаем буферы для аттрибутов вершин
    glGenBuffers(ARRAY_SIZE_IN_ELEMENTS(m_Buffers), m_Buffers);

    bool Ret = false;

    <b>m_pScene = m_Importer</b>.ReadFile(Filename.c_str(), aiProcess_Triangulate | aiProcess_GenSmoothNormals |


    aiProcess_FlipUVs);

    if (m_pScene) {
        <b>m_GlobalInverseTransform = m_pScene-&gt;mRootNode-&gt;mTransformation;
        m_GlobalInverseTransform.Inverse();</b>
        Ret = InitFromScene(<b>m_pScene</b>, Filename);
    }
    else {
        printf("Error parsing '%s': '%s'\n", Filename.c_str(),<b> m_Importer</b>.GetErrorString());
    }

    // Убедимся, что VAO не изменится из вне
    glBindVertexArray(0);

    return Ret;
}
</code></pre>
<p>
    Вот обновленная точка входа в класс Mesh, изменения выделены жирным. Некоторые стоит отметить. Первое, что importer
    и объект aiScene - свойства класса, а не стек переменных. Причина в том, что в нам придется в рантайме снова и снова
    возвращаться к объекту aiScene, для этого мы должны расширить область видимости importer и сцены. В настоящей игре
    вы возможно захотите скопировать данные для хранения в более оптимизированном формате, но для обучения хватит и этого.
</p>
<p>
    Второе изменение -  матрица преобразования корневого элемента извлечена, найдена обратная к ней, и записана обратно.
    Это потребуется в дальнейшем. Также заметьте, что код для нахождения обратной матрицы был скопирован из Assimp в
    наш класс Matrix4f.
</p>
</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">mesh.h:69</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>struct VertexBoneData
{
    uint IDs[NUM_BONES_PER_VEREX];
    float Weights[NUM_BONES_PER_VEREX];
}
</code></pre>
</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">mesh.cpp:109</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>bool Mesh::InitFromScene(const aiScene* pScene, const string&amp; Filename)
{
    ...
    vector&lt;VertexBoneData&gt; Bones;
    ...
    Bones.resize(NumVertices);
    ...
    glBindBuffer(GL_ARRAY_BUFFER, m_Buffers[BONE_VB]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Bones[0]) * Bones.size(), &amp;Bones[0], GL_STATIC_DRAW);
    glEnableVertexAttribArray(BONE_ID_LOCATION);
    <b>glVertexAttribIPointer</b>(BONE_ID_LOCATION, 4, GL_INT, sizeof(VertexBoneData), (const GLvoid*)0);
    glEnableVertexAttribArray(BONE_WEIGHT_LOCATION);
    glVertexAttribPointer(BONE_WEIGHT_LOCATION, 4,
                          GL_FLOAT, GL_FALSE, sizeof(VertexBoneData), (const GLvoid*)16);
    ...
}
</code></pre>
<p>
    Структура выше содержит все, что нам потребуется на уровне вершин. По-умолчанию, нам достаточно пространства для 4
    костей (ID и вес на кость). VertexBoneData устроена похожим образом, что упрощает передачу в шейдер. У нас уже
    имеется позиция, координаты текстур и нормаль, привязанные к позициям 0, 1 и 2 соответственно. Хотя, мы настроили
    наш VAO для привязывания ID кости под позицией 3 и вес под 4. Важно заметить, что мы используем
    glVertexAttrib<b>I</b>Pointer вместо glVertexAttribPointer для привязывания ID. Причина в том, что ID - целое число,
    а не значение с плавующей точкой. Не упустите это или данные в шейдере повредятся.
</p>
</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">mesh.cpp:215</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>void Mesh::LoadBones(uint MeshIndex, const aiMesh* pMesh, vector<vertexbonedata>&amp; Bones)
{
    for (uint i = 0 ; i &lt; pMesh-&gt;mNumBones ; i++) {
        uint BoneIndex = 0;
        string BoneName(pMesh-&gt;mBones[i]-&gt;mName.data);

        if (m_BoneMapping.find(BoneName) == m_BoneMapping.end()) {
            BoneIndex = m_NumBones;
            m_NumBones++;
            BoneInfo bi;
            m_BoneInfo.push_back(bi);
        }
        else {
            BoneIndex = m_BoneMapping[BoneName];
        }

        m_BoneMapping[BoneName] = BoneIndex;
        m_BoneInfo[BoneIndex].BoneOffset = pMesh-&gt;mBones[i]-&gt;mOffsetMatrix;

        for (uint j = 0 ; j &lt; pMesh-&gt;mBones[i]-&gt;mNumWeights ; j++) {
            uint VertexID = m_Entries[MeshIndex].BaseVertex +
                            pMesh-&gt;mBones[i]-&gt;mWeights[j].mVertexId;
            float Weight  = pMesh-&gt;mBones[i]-&gt;mWeights[j].mWeight;
            Bones[VertexID].AddBoneData(BoneIndex, Weight);
        }
    }
}
</vertexbonedata></code></pre>
<p>
    Функция выше загружает информацию о кости для одного объекта aiMesh. Она вызывается из Mesh::InitMesh(). Кроме
    заполнения структуры VertexBoneData эта функция так же обновляет связи между именем кости и номером ID (индекс
    определяется при запуске) и записыват матрицу смещения в вектор, зависящий от id кости. Обратим внимание на то, как
    вычисляется id кости. Так как id соответствует одному мешу и мы храним все меши в одном векторе, то мы добавляем
    к базовому значению id вершины текущего aiMesh id вершины из массива mWeights для получения абсолютного значения.
</p>
</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">mesh.cpp:31</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>void Mesh::VertexBoneData::AddBoneData(uint BoneID, float Weight)
{
    for (uint i = 0 ; i &lt; ARRAY_SIZE_IN_ELEMENTS(IDs) ; i++) {
        if (Weights[i] == 0.0) {
            IDs[i]     = BoneID;
            Weights[i] = Weight;
            return;
        }
    }

    // Никогда не должны оказаться здесь - костей больше, чем мы рассчитывали
    assert(0);
}
</code></pre>
<p>
    Эта вспомогательная функция находит свободные слоты в структуре VertexBoneData и размещает внутри id и вес кости.
    Некоторые вершины находятся под влиянием менее, чем 4 кости, но т.к. вес не существующей кости равен 0 (подробнее в
    конструкторе VertexBoneData), это значит, что мы можем использовать эти вычисления для любого кол-ва костей.
</p>
</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">mesh.cpp:469</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>Matrix4f Mesh::BoneTransform(float TimeInSeconds, vector&lt;Matrix4f&gt;&amp; Transforms)
{
    Matrix4f Identity;
    Identity.InitIdentity();

    float TicksPerSecond = m_pScene-&gt;mAnimations[0]-&gt;mTicksPerSecond != 0 ?
                           m_pScene-&gt;mAnimations[0]-&gt;mTicksPerSecond : 25.0f;

    float TimeInTicks = TimeInSeconds * TicksPerSecond;
    float AnimationTime = fmod(TimeInTicks, m_pScene-&gt;mAnimations[0]-&gt;mDuration);

    ReadNodeHeirarchy(AnimationTime, m_pScene-&gt;mRootNode, Identity);

    Transforms.resize(m_NumBones);

    for (uint i = 0 ; i &lt; m_NumBones ; i++) {
        Transforms[i] = m_BoneInfo[i].FinalTransformation;
    }
}
</code></pre>
<p>
    Загрузка данных костей на уровне вершин, которую мы видили ранее, происходит только 1 раз при загрузке меша. Настало
    время для второй чати - вычисление преобразования кости, которое будет загружаться в шейдер каждый кадр. Функция
    выше - входная точка в алгоритм. При вызове указываются текущее время в секундах (может быть дробным) и массив
    матриц, которые мы должны обновить. Относительное время мы найдем внутри цикла анимации и обработки листов иерархии.
    Результат - массив преобразований, которые вернутся в место вызова.
</p>
</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">mesh.cpp:424</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>void Mesh::ReadNodeHeirarchy(float AnimationTime, const aiNode* pNode, const Matrix4f&amp; ParentTransform)
{
    string NodeName(pNode-&gt;mName.data);

    const aiAnimation* pAnimation = m_pScene-&gt;mAnimations[0];

    Matrix4f NodeTransformation(pNode-&gt;mTransformation);

    const aiNodeAnim* pNodeAnim = FindNodeAnim(pAnimation, NodeName);

    if (pNodeAnim) {
        // Интерполируем масштабирование и генерируем матрицу преобразования масштаба
        aiVector3D Scaling;
        CalcInterpolatedScaling(Scaling, AnimationTime, pNodeAnim);
        Matrix4f ScalingM;
        ScalingM.InitScaleTransform(Scaling.x, Scaling.y, Scaling.z);

        // Интерполируем вращение и генерируем матрицу вращения
        aiQuaternion RotationQ;
        CalcInterpolatedRotation(RotationQ, AnimationTime, pNodeAnim);
        Matrix4f RotationM = Matrix4f(RotationQ.GetMatrix());

        //  Интерполируем смещение и генерируем матрицу смещения
        aiVector3D Translation;
        CalcInterpolatedPosition(Translation, AnimationTime, pNodeAnim);
        Matrix4f TranslationM;
        TranslationM.InitTranslationTransform(Translation.x, Translation.y, Translation.z);

        // Объединяем преобразования
        NodeTransformation = TranslationM * RotationM * ScalingM;
    }

    Matrix4f GlobalTransformation = ParentTransform * NodeTransformation;

    if (m_BoneMapping.find(NodeName) != m_BoneMapping.end()) {
        uint BoneIndex = m_BoneMapping[NodeName];

        m_BoneInfo[BoneIndex].FinalTransformation = m_GlobalInverseTransform *
                                                    GlobalTransformation *
                                                    m_BoneInfo[BoneIndex].BoneOffset;
    }

    for (uint i = 0 ; i &lt; pNode-&gt;mNumChildren ; i++) {
        ReadNodeHeirarchy(AnimationTime, pNode-&gt;mChildren[i], GlobalTransformation);
    }
}
</code></pre>
<p>
    Эта функция обходит листы дерева и генерирует итоговое преобразование для каждого листа / кости согласно указанному
    времени анимации. Она ограничена в том плане, что мы можем использовать только 1 анимационную последовательность.
    Если вы хотите поддерживать одновременно несколько анимаций, то вам потребуется сообщить название анимации и искать
    по нему в массиве m_pScene-&gt;mAnimations[]. Код выше достаточно хорош для тестового меша, который мы используем.
</p>
<p>
    Преобразования для кости инициализируются из свойства листа mTransformation. Если лист не соответствует какой-либо
    кости, то это и будет итоговым преобразованием. А если соответствует, то мы перезаписываем его новой матрицей.
    Это происходит следующим образом: для начала мы ищем название листа в массиве каналов анимации. Затем мы интерполируем
    вектор масштабирования, кватернион вращения и вектор смещения по времени анимации. Мы комбинируем из них единую
    матрицу и умножаем на матрицу, полученную как параметр (называется GlobablTransformation). Эта функция рекурсивна и
    вызывается для корневого листа, а матрица GlobablTransformation - единичная. Каждый лист вызывает эту функцию
    рекурсивно для всех своих потомков и передает собственное преобразование как GlobalTransformation. Так как мы
    проходим сверху вниз, то получаем скомбинированную матрицу в каждом листе.
</p>
<p>
    Массив m_BoneMapping отображает название листа в индекс, который мы сгенерировали и мы используем этот индекс как
    номер в массиве m_BoneInfo, где хранится матрица итогового преобразования. Полное преобразование вычисляется так:
    мы начинаем с матрицы смещения листа, которая переводит вершины из локального пространства в пространство кости.
    Затем мы перемножаем с комбинированными преобразованиями всех узлов родителя плюс специальное преобразование,
    которое мы вычислили для листа согласно времени анимации.
</p>
<p>
    Заметим, что мы используем код Assimp для всего матана. Я не вижу смысла в дублировании кода из библиотеки в наш,
    лучше использовать Assimp.
</p>
</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">mesh.cpp:383</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>void Mesh::CalcInterpolatedRotation(aiQuaternion&amp; Out, float AnimationTime, const aiNodeAnim* pNodeAnim)
{
    // для интерполирования требуется не менее 2 значений...
    if (pNodeAnim-&gt;mNumRotationKeys == 1) {
        Out = pNodeAnim-&gt;mRotationKeys[0].mValue;
        return;
    }

    uint RotationIndex = FindRotation(AnimationTime, pNodeAnim);
    uint NextRotationIndex = (RotationIndex + 1);
    assert(NextRotationIndex &lt; pNodeAnim-&gt;mNumRotationKeys);
    float DeltaTime = pNodeAnim-&gt;mRotationKeys[NextRotationIndex].mTime -
                      pNodeAnim-&gt;mRotationKeys[RotationIndex].mTime;
    float Factor = (AnimationTime - (float)pNodeAnim-&gt;mRotationKeys[RotationIndex].mTime) / DeltaTime;
    assert(Factor &gt;= 0.0f &amp;&amp; Factor &lt;= 1.0f);
    const aiQuaternion&amp; StartRotationQ = pNodeAnim-&gt;mRotationKeys[RotationIndex].mValue;
    const aiQuaternion&amp; EndRotationQ   = pNodeAnim-&gt;mRotationKeys[NextRotationIndex].mValue;
    aiQuaternion::Interpolate(Out, StartRotationQ, EndRotationQ, Factor);
    Out = Out.Normalize();
}
</code></pre>
<p>
    Этот метод интерполирует кватернион вращения указанного канала согласно времени анимации (вспомним, что этот канал
    хранит массив ключевых кватернионов). Сначала мы находим индекс ключевого кватерниона, который до требуемого
    времени анимации. Мы вычисляем коэффициент между расстоянием от этого ключа до требуемого времени и расстояние
    от времени анимации до следующего ключа. При интерполировании будет использоваться этот коэффициент. Мы используем
    код Assimp для интерполяции и нормализации результата. Аналогичные методы для позиции и масштабирования очень
    похожи и не приведены здесь.
</p>
</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">mesh.cpp:335</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>uint Mesh::FindRotation(float AnimationTime, const aiNodeAnim* pNodeAnim)
{
    assert(pNodeAnim-&gt;mNumRotationKeys &gt; 0);

    for (uint i = 0 ; i &lt; pNodeAnim-&gt;mNumRotationKeys - 1 ; i++) {
        if (AnimationTime &lt; (float)pNodeAnim-&gt;mRotationKeys[i + 1].mTime) {
            return i;
        }
    }

    assert(0);
}
</code></pre>
<p>
    Этот дополнительный метод находит ключевое вращение непосредственно перед временем анимации. Если мы имеем N
    ключевых вращений, то результат может быть от 0 до N-2. Время анимации всегда внутри продолжительности канала,
    поэтому последний элемент (N-1) - не подходящее значение.
</p>
</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">skinning.glsl</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>struct VSInput
{
    vec3  Position;
    vec2  TexCoord;
    vec3  Normal;
    <b>ivec4 BoneIDs;
    vec4  Weights;</b>
};

interface VSOutput
{
    vec2 TexCoord;
    vec3 Normal;
    vec3 WorldPos;
};

const int MAX_BONES = 100;

uniform mat4 gWVP;
uniform mat4 gWorld;
uniform mat4 gBones[MAX_BONES];

shader VSmain(in VSInput VSin:0, out VSOutput VSout)
{
    mat4 BoneTransform = gBones[VSin.BoneIDs[0]] * VSin.Weights[0];
    BoneTransform     += gBones[VSin.BoneIDs[1]] * VSin.Weights[1];
    BoneTransform     += gBones[VSin.BoneIDs[2]] * VSin.Weights[2];
    BoneTransform     += gBones[VSin.BoneIDs[3]] * VSin.Weights[3];

    vec4 PosL      = BoneTransform * vec4(VSin.Position, 1.0);
    gl_Position    = gWVP * PosL;
    VSout.TexCoord = VSin.TexCoord;
    vec4 NormalL   = BoneTransform * vec4(VSin.Normal, 0.0);
    VSout.Normal   = (gWorld * NormalL).xyz;
    VSout.WorldPos = (gWorld * PosL).xyz;
}
</code></pre>
<p>
    Теперь, когда мы закончили с классом меша давайте рассмотрим, что нам нужно на уровне шейдера. Для начала мы добавим
    массивы ID костей и веса в структуру VSInput. Затем появился новый uniform массив, который содержит все
    преобразования костей. В самом шейдере мы вычисляем итоговое преобразование кости как комбинацию матриц вершины и
    веса. Итоговая матрица используется для преобразования позиции и нормали их пространства кости в локальное. Дальше
    все как обычно.
</p>
</div></article><article class="hero clearfix"><div class="col_33"> <p class="message">tutorial38.cpp:140</p> </div></article><article class="hero clearfix"><div class="col_100">
<pre><code>float RunningTime = CalcRunningTime();

m_mesh.BoneTransform(RunningTime, Transforms);

for (uint i = 0 ; i &lt; Transforms.size() ; i++) {
     m_pEffect-&gt;SetBoneTransform(i, Transforms[i]);
}
</code></pre>
<p>
    Осталось только собрать все вместе. Это легко делается кодом выше. Функция CalcRunningTime() возвращает прошедшее
    время в секундах от начала запуска приложения (заметим, что число с плавующей точкой - подмножество дробных чисел).
</p>
<p>
    Если вы все сделали правильно, то результат должен быть похож на 
    <a href="http://www.youtube.com/watch?v=aHUTof9S8mM">это</a>.
</p>
