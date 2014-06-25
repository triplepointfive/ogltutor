---
title: Урок 22 - Загрузка моделей через Assimp
---
<a href="http://ogldev.atspace.co.uk/www/tutorial22/tutorial22.html"><h2>Теоретическое введение</h2></a>
<p>До сих пор мы использовали созданные вручную модели. Как вы можете заметить, процесс указания позиции и прочих атрибутов для каждой вершины не очень оптимален. Куб, пирамида или другие простые поверхности еще терпимы, а вот например человеческое лицо? В мире игр или коммерческих приложений процесс создания полигональной сетки перекладывается на 3D моделеров, которые используют программы наподобие <a href="http://www.blender.org/">Blender</a>, <a href="http://usa.autodesk.com/maya/">Maya</a> или <a href="http://usa.autodesk.com/3ds-max/">3ds Max</a>. Эти приложения предоставляют продвинутые инструменты, которые помогут моделеру создать даже чрезвычайно сложные модели. Когда модель завершена, она сохраняется в файл в одном из многочисленных форматов. Этот файл содержит все геометрические данные.  Теперь он может быть загружен в движок (при условии, что данный формат поддерживается), и его содержимое может заполнить вершинный и индексный буферы для рендера. Знание того, как разобрать тот или иной формат 
файлов, и возможность загрузить его данные крайне важны для того, что бы перевести программу на следующий уровень.</p>
<p>Разработка своего загрузчика может занять довольно много времени. Если вы хотите, что бы была возможность загружать модели из различных источников, то потребуется изучить каждый формат и написать для каждого свой загрузчик. Некоторые форматы простые, но от некоторых идет пар из ушей, и на них уйдет масса времени, причем это не является целью 3D программирования. Поэтому метод, показанный в этом уроке - это использование внешней библиотеки для разбора и загрузки моделей из файла.</p>
<p><a href="http://assimp.sourceforge.net/">Open Asset Import Library</a> или просто Assimp - это свободная библиотека, которая поддерживает множество форматов, включая наиболее популярные. Она кроссплатформеная и доступна и под Linux и под Windows. В программах на C/C++ использовать ее очень просто.</p>
<p>В данном уроке не так и много теории. Давайте скорее погрузимся в Assimp!</p>
<p>Важно отметить, что версии assimp бинарно не совместимы, а так же используют различные названия для файлов-заголовков. В данной серии уроков используется версия 3.0. Если ваш дистрибутив предлагает старые версии (например 2.0 у Fedora), то возможно потребуется изменить названия заголовков с assimp/Importer.hpp assimp/scene.h assimp/postprocess.h на assimp.hpp, aiScene.h aiPostProcess.h соответственно.</p>


<a href="https://github.com/triplepointfive/ogldev/tree/master/tutorial22"><h2>Прямиком к коду!</h2></a>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.h:50</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>class Mesh
{
public:
	Mesh();

	~Mesh();

	bool LoadMesh(const std::string&amp; Filename);

	void Render();

private:
	bool InitFromScene(const aiScene* pScene, const std::string&amp; Filename);
	void InitMesh(unsigned int Index, const aiMesh* paiMesh);
	bool InitMaterials(const aiScene* pScene, const std::string&amp; Filename);
	void Clear();

#define INVALID_MATERIAL 0xFFFFFFFF

	struct MeshEntry {
		MeshEntry();

		~MeshEntry();

		bool Init(const std::vector&lt;Vertex&gt;&amp; Vertices,
		const std::vector&lt;unsigned int&gt;&amp; Indices);

		GLuint VB;
		GLuint IB;
		unsigned int NumIndices;
		unsigned int MaterialIndex;
	};

	std::vector&lt;MeshEntry&gt; m_Entries;
	std::vector&lt;Texture*&gt; m_Textures;
};
</code></pre>
<p>Класс меш (или полигональной сетки) представляет собой интерфейс между Assimp и нашей программой OpenGL. Объект этого класса принимает имя файла как параметр в функцию LoadMesh(), используя Assimp для загрузки модели и создания вершинного, индексного буферов и объекта текстуры, который содержит данные в форме, понятной нашей программе. Для того, что бы рендерить меш мы будем использовать функцию Render(). Внутренняя структура класса соответствует способу загрузки моделей Assimp. Он использует объект aiScene для представления загруженного меша. Объект aiScene хранит структуру меша, которая инкапсулирует части модели. Должна быть по крайней мере одна структура меша в объекте aiScene. Сложные модели могут хранить сразу несколько структур мешей. Член класса меша m_Entries - это вектор из MeshEntry, в которых каждая структура соответствует объекту aiScene. Эта структура хранит вершинный буфер, буфер индексов и индексы материала. Пока что материал просто текстура, и так как MeshEntry может поставлять его, то от нас потребуется отдельный вектор (m_Textures). MeshEntry::MaterialIndex указывает на одну из текстур в m_Textures.</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.cpp:77</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>bool Mesh::LoadMesh(const std::string&amp; Filename)
{
	// Release the previously loaded mesh (if it exists)
	Clear();
    
	bool Ret = false;
	Assimp::Importer Importer;

	const aiScene* pScene = Importer.ReadFile(Filename.c_str(), aiProcess_Triangulate | aiProcess_GenSmoothNormals | aiProcess_FlipUVs);
    
	if (pScene) {
		Ret = InitFromScene(pScene, Filename);
	}
	else {
		printf("Error parsing '%s': '%s'\n", Filename.c_str(), Importer.GetErrorString());
	}

	return Ret;
}
</code></pre>
<p>Эта функция - начальная точка загрузки меша. Мы создаем экземпляр класса Assimp::Importer в стеке и вызываем его функцию ReadFile. Функция принимает 2 параметра: полный путь к файлу модели и маску опций пост-обработки.  Assimp способен выполнять множество действий над моделью после ее загрузки. Например создать нормали в случае их отсутствия, оптимизировать структуру модели для улучшения производительности и другие. Полный список опций доступен по <a href="http://assimp.sourceforge.net/lib_html/ai_post_process_8h.html">ссылке</a>. В этом уроке мы используем 3 опции: aiProcess_Triangulate, которая перестроит в треугольники полигоны других типов. Например, меш из квадратов может быть переведен в треугольники посредством деления каждого квадрата на 2 треугольника. 2 опция, aiProcess_GenSmoothNormals, создаст нормали вершин в случае, когда оригинальная модель их не имеет. Заметим, что опции пост-обработки не перекрывают друг друга, то есть вы можете использовать сразу несколько указав их через "|". Последняя 
опция, aiProcess_FlipUVsv, вращает текстуру относительно оси Y. Это требуется для корректного рендера модели из Quake, которая приведена в демо к уроку. Вам нужно будет адаптировать параметры, которые вы используете в соответствии с входными данными. Если меш загружен без ошибок, мы получим указатель на объект<a href="http://assimp.sourceforge.net/lib_html/structai_scene.html"> aiScene</a>. Он хранит все данные, разделенные в структуре <a href="http://assimp.sourceforge.net/lib_html/structai_mesh.html">aiMesh</a>. Затем мы вызываем функцию InitFromScene() для инициализации объекта меша.</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.cpp:97</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>bool Mesh::InitFromScene(const aiScene* pScene, const std::string&amp; Filename)
{  
	m_Entries.resize(pScene-&gt;mNumMeshes);
	m_Textures.resize(pScene-&gt;mNumMaterials);

	// Initialize the meshes in the scene one by one
	for (unsigned int i = 0 ; i &lt; m_Entries.size() ; i++) {
		const aiMesh* paiMesh = pScene-&gt;mMeshes[i];
		InitMesh(i, paiMesh);
	}

	return InitMaterials(pScene, Filename);
}
</code></pre>
<p>Инициализация меша начинается с выделения пространства для его данных и вектора текстуры для всех мешей и материалов, которые нам потребуются. Их количество - это свойства объекта aiScene mNumMeshes и mNumMaterials соответственно. После мы просматриваем массив mMeshes и объект aiScene и инициализируем записи меша одну за другой. Наконец, материал проинициализирован.</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.cpp:111</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>void Mesh::InitMesh(unsigned int Index, const aiMesh* paiMesh)
{
	m_Entries[Index].MaterialIndex = paiMesh-&gt;mMaterialIndex;
    
	std::vector&lt;Vertex&gt; Vertices;
	std::vector&lt;unsigned int&gt; Indices;	
		...
</code></pre>
<p>Инициализация меша начинается с записи его индексов. Они будут использованы во время рендера для привязки требуемой текстуры. После мы создаем 2 вектора STL для хранения содержимого вершинного и буферного индексов. Вектор STL имеет хорошее свойство записи его содержимого в непрерывном буфере. Это упрощает загрузку данных в буфер OpenGL (используя функцию glBufferData()).</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.cpp:118</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>	const aiVector3D Zero3D(0.0f, 0.0f, 0.0f);

	for (unsigned int i = 0 ; i &lt; paiMesh-&gt;mNumVertices ; i++) {
		const aiVector3D* pPos      = &amp;(paiMesh-&gt;mVertices[i]);
		const aiVector3D* pNormal   = &amp;(paiMesh->mNormals[i]);
		const aiVector3D* pTexCoord = paiMesh-&gt;HasTextureCoords(0) ? &amp;(paiMesh-&gt;mTextureCoords[0][i]) : &amp;Zero3D;

		Vertex v(Vector3f(pPos-&gt;x, pPos-&gt;y, pPos-&gt;z),
					Vector2f(pTexCoord-&gt;x, pTexCoord-&gt;y),
					Vector3f(pNormal-&gt;x, pNormal-&gt;y, pNormal-&gt;z));

		Vertices.push_back(v);
	}
	...
</code></pre>
<p>Здесь мы готовим содержимое буфера вершин путем заполнения вектора вершин. Мы используем следующие атрибуты класса aiMesh:</p>
<ol><li>mNumVertices - количество вершин.</li>
<li>mVertices - массив mNumVertices - вектор, который хранит координаты.</li>
<li>mNormals - массив mNumVertices - вектор нормалей.</li>
<li>mTextureCoords - массив векторов mNumVertices, который хранит координаты текстуры. Это двумерный массив, так как каждая вершина может хранить несколько координат текстуры.</li></ol>
<p>Итого мы имеем 3 отдельных массива, которые хранят все, что нам требуется для вершин, и нам нужно выделить каждый атрибут из соответствующего массива что бы получить итоговую структуру вершины. Эта структура будет помещена в вектор вершин (сохраняя тот же индекс, что и в массиве aiMesh). Заметим, что некоторые модели не имеют координат текстур, поэтому прежде чем взаимодействовать с массивом mTextureCoords (и скорее всего словить ошибку сегментации) мы проверим имеются ли координаты текстуры через HasTextureCoords(). Кроме того, меш может иметь несколько координат на вершину. В этом уроке мы упрощаем жизнь используя только первые координаты. Вот почему двумерный массив mTextureCoords всегда обращается к первой строке. Поэтому функция HasTextureCoords() всегда вызывается для первой строки. Если координаты отсутствуют, то структура вершин будет создана с нулевым вектором.</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.cpp:132</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>	for (unsigned int i = 0 ; i &lt; paiMesh-&gt;mNumFaces ; i++) {
		const aiFace&amp; Face = paiMesh-&gt;mFaces[i];
		assert(Face.mNumIndices == 3);
		Indices.push_back(Face.mIndices[0]);
		Indices.push_back(Face.mIndices[1]);
		Indices.push_back(Face.mIndices[2]);
	}
	...
</code></pre>
<p>Далее мы создаем буфер индексов. Свойство mNumFaces класса aiMesh сообщает как много имеется полигонов и массив mFaces хранит эти данные (т.е. индексы вершин). Для начала мы удостоверяемся, что их по 3 в полигоне (да, мы указывали, что бы модель была составленна из треугольников, но лишняя проверка не помешает). После мы извлекаем индексы из массива mIndices и помещаем в вектор Indices.</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.cpp:140</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>		m_Entries[Index].Init(Vertices, Indices);
}
</code></pre>
<p>Наконец, структура MeshEntry проинициализированна с помощью векторов вершин и индексов. В функции MeshEntry::Init() ничего нового, поэтому она не представлена здесь. В ней используются glGenBuffer(), glBindBuffer() и glBufferData() для создания и заполнения буферов вершин и индексов. Для деталей смотрите исходники.</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.cpp:143</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>bool Mesh::InitMaterials(const aiScene* pScene, const std::string&amp; Filename)
{
	for (unsigned int i = 0 ; i &lt; pScene-&gt;mNumMaterials ; i++) {
		const aiMaterial* pMaterial = pScene-&gt;mMaterials[i];
		...
</code></pre>
<p>Эта функция загружает все текстуры, которые используются в модели. Атрибут mNumMaterials в объекте хранит количество материалов, и mMaterials - это массив указателей на структуры <a href="http://assimp.sourceforge.net/lib_html/structai_material.html">aiMaterials</a>. Структура aiMaterial крайне сложно устроена, но это скрыто под небольшим API. В целом материал организован как стек текстур и для наилучшего результата должны быть написаны функции прозрачности и силы. Например, 1 функция может сказать нам, что требуется сложить цвет из первой текстуры с цветом из второй, а функция силы скажет уменьшить результат наполовину. Обе функции реализованы в aiMaterial и могут быть извлечены. Для простоты наш шейдер света игнорирует этот функционал и просто использует текстуры как есть.</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.cpp:165</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>		m_Textures[i] = NULL;
		if (pMaterial-&gt;GetTextureCount(aiTextureType_DIFFUSE) &gt; 0) {
			aiString Path;

			if (pMaterial-&gt;GetTexture(aiTextureType_DIFFUSE, 0, &amp;Path, NULL, NULL, NULL, NULL, NULL) == AI_SUCCESS) {
				std::string FullPath = Dir + "/" + Path.data;
				m_Textures[i] = new Texture(GL_TEXTURE_2D, FullPath.c_str());

				if (!m_Textures[i]-&gt;Load()) {
					printf("Error loading texture '%s'\n", FullPath.c_str());
					delete m_Textures[i];
					m_Textures[i] = NULL;
					Ret = false;
				}
			}
		}
		...
</code></pre>
<p>Материал может содержать несколько текстур, и не все из них содержат цвет. Например, текстура может быть картой высот или нормалей, смещения и прочие. Так как наш шейдер света на данный момент использует единственную текстуру, то нам интересна только диффузная текстура. Поэтому мы проверяем как много присутствует диффузных текстур через функцию aiMaterial::GetTextureCount(). Она принимает тип текстуры как параметр и возвращает количество текстур данного типа. Первый параметр и есть их тип. После идет индекс, который мы всегда назначаем в 0. После мы указываем адрес строки, в которой будет имя файла текстуры. Наконец, 5 параметров адресов, которые помогут подхватить некоторые параметры текстуры, такие как прозрачность, тип отображения, операции над текстурой и т.д. Они не обязательны, и поэтому мы их игнорируем пока что, передав NULL. Нам интересны только имена файлов и мы связываем их с директорией, в которой расположена модель. Папка извлекается в начале функции (не написано здесь), и мы предполагаем, 
что модель и текстуры в одной папке. Если структура каталогов сложнее, возможно потребуется искать текстуру где-то еще. Мы создаем объект текстуры и загружаем его как обычно.</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.cpp:187</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>		if (!m_Textures[i]) {
			m_Textures[i] = new Texture(GL_TEXTURE_2D, "./white.png");
			Ret = m_Textures[i]-&gt;Load();
		}
	}

	return Ret;
}
</code></pre>
<p>Кусок кода выше - обходной путь проблем, с которыми вы можете столкнуться при загрузке моделей из сети. Бывает, что модель не содержит текстуру, и в этом случае вы ничего не увидите, поскольку цвет, полученный из несуществующей текстуры - черный. Один из способов борьбы с этим - проверка в шейдере или даже использование еще одного шейдера для данной ситуации. Но в этом уроке мы просто будем использовать текстуру, которая состоит из 1 белого пикселя. Это будет выглядеть не очень здорово, но по крайней мере вы будете видеть хоть что-то. Эта текстура имеет малый размер и позволяет использовать один шейдер для обоих случаев.</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">mesh.cpp:197</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>void Mesh::Render()
{
	glEnableVertexAttribArray(0);
	glEnableVertexAttribArray(1);
	glEnableVertexAttribArray(2);

	for (unsigned int i = 0 ; i &lt; m_Entries.size() ; i++) {
		glBindBuffer(GL_ARRAY_BUFFER, m_Entries[i].VB);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid*)12);
		glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid*)20);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_Entries[i].IB);

		const unsigned int MaterialIndex = m_Entries[i].MaterialIndex;

		if (MaterialIndex &lt; m_Textures.size() &amp;&amp; m_Textures[MaterialIndex]) {
			m_Textures[MaterialIndex]-&gt;Bind(GL_TEXTURE0);
		}

		glDrawElements(GL_TRIANGLES, m_Entries[i].NumIndices, GL_UNSIGNED_INT, 0);
	}

	glDisableVertexAttribArray(0);
	glDisableVertexAttribArray(1);
	glDisableVertexAttribArray(2);
}
</code></pre>
<p>Эта функция инкапсулирует рендер меша и выделяет его из центра приложения (в отличии от предыдущих уроков). Массив m_Entries просматривается, и вершинный и индексный буферы разрешаются. Индекс материала используется для получения объекта текстуры из массива m_Texture, после чего то же привязывается к шейдеру. Наконец, вызывается функция отрисовки. Теперь вы можете иметь несколько мешей, которые загружаются из файла и рендерятся один за другим через the Mesh::Render().</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">glut_backend.cpp:115</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>glEnable(GL_DEPTH_TEST);
</code></pre>
<p>Последнее, что нам требуется изучить, но было упущено в предыдущих уроках. Если вы просто загрузите модель используя код выше, то столкнетесь с аномалиями на сцене. Причина в том, что треугольники, которые дальше от камеры, рисуются поверх тех, которые ближе. Для того, что бы исправить это недоразумение, мы включаем широко известный тест глубины (или Z-тест). Когда он запущен, то растеризатор сравнивает глубину всех пикселей, которые должны быть отрисованы в одной точке экрана. Пиксель, чей цвет использован в отрисовке - "победитель" теста глубины (т.е. ближе к камере). Z-тест не включен по умолчанию, и код выше запускает его (часть инициализации OpenGL в функции GLUTBackendRun()). Это только 1 часть из 3 требуемых для теста глубины (остальные ниже).</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">glut_backend.cpp:73</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>glutInitDisplayMode(GLUT_DOUBLE|GLUT_RGBA|GLUT_DEPTH);
</code></pre>
<p>Вторая часть инициализации буфера глубины. Для того, что бы сравнивать глубину 2 пикселей, глубина "старого" пикселя должна быть где-то сохранена (глубина "нового пикселя доступна их вершинного шейдера). Для этой цели у нас есть специальный буфер, известный как буфер глубины (или Z буфер). Он имеет те же пропорции, что и у экрана, поэтому каждый пиксель в буфере цвета имеет соответствующий слот и в буфере глубины. Слот всегда хранит глубину ближайшего пикселя, которая используется для сравнения в тесте глубины.</p>
</div></article><article class="hero clearfix"><div class="col_33">
<p class="message">main.cpp</p>
</div></article><article class="hero clearfix"><div class="col_100">
<pre><code>glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);	
</code></pre>
<p>Последнее что мы должны сделать - это очистить буфер глубины в начале нового кадра. Если мы не сделаем этого, то он сохранит старые значения от предыдущего кадра, и глубина новых пикселей так же будет сравниваться со старыми значениями. Как вы можете представить, это вызовет серьезные повреждения (попробуйте!). Функция glClear() принимает маску буферов, которые необходимо очистить. До этого мы очищали буфер цвета. Пришло время и для буфера глубины.</p>
 