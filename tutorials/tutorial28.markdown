---
title: Урок 28 - Система частиц и Transform Feedback
---



<p>
<i>Система частиц (Particle System)</i> - это общее название огромного количества методов, симулирующих природные явления, такие как дым, пыль, фейрверк, дождь и т.д. Главное отличие всех этих явлений в том, что они состоят из большого числа частиц, которые двигаются вместе в каком-либо направлении, в зависимости от явления.
</p>
<p>
Для того, что бы симулировать природное явление, составленное из частиц, мы обычно задаем позицию так же, как и другие атрибуты для каждой частицы (скорость, цвет и прочие), а после один раз за кадр выполняем следующие шаги:
</p>
<ol>
<li>Обновляем атрибуты каждой частицы. Этот шаг обычно включает некоторые математические вычисления (начиная от простых и заканчивая чрезвычайно сложными - в зависимости от типа явления).</li>
<li>Рендерим частицы (либо как обычные цветные точки, либо как текстуру, которая будет отображена billboard).</li>
</ol>

<p>
Раньше шаг 1 обычно перекладывался на CPU (процессор). Приложение получало доступ к вершинному буферу, проходило по его содержимому и обновляло атрибуты абсолютно каждой частицы. Шаг 2 не имеет никаких принципиальных отличий, поэтому он выполнялся GPU (граффический процессор), как и остальной рендер. Но у такого подхода 2 проблемы:
</p>
<ol>
<li>Обновление частиц на CPU требует от драйвера OpenGL копировать содержимое вершинного буфера из памяти GPU (в случае дискретных видеокарт по шине PCI) в память CPU. Явления, которые нам интересны, обычно состоят из огромного количества частиц. 10,000 частиц не редкое число в данной области. Если каждая частица занимает 64 Кбайта, и мы работаем с частотой кадров равной 60 (обычное значение), то это значит, что мы должны отправить туда и обратно 640K из GPU в CPU 60 раз в секунду. Это будет иметь негативные последствия на производительности приложения. При росте количества частиц эффект только усиливается.</li>
<li>Обновление атрибутов частиц означает запуск одной и той же математической формулы с различными входящими данными. Это прекрасный пример распределенных вычислений, в которых так хорош GPU. Обработка же на CPU означает очередность процесса обновления. Если у вашего процессора несколько ядер, мы можем воспользоваться ими и уменьшить общее время обработки, но это потребует дополнительной работы от приложения. Запуск процесса обновления на GPU означает, что мы легко и просто получим параллельные вычисления.</li>
</ol>
<p>
DirectX10 ввел новый функционал, известный как <i>Stream Output</i>, который очень удобен для системы частиц. OpenGL не отставал и ввел в версии 3.0 аналог под названием <i>Transform Feedback</i>. Идея этого функционала в том, что мы можем присоединить специальный тип буфера называемый <i>Transform Feedback Buffer</i> сразу после GS (или VS если GS отсутствует) и послать наши преобразованные примитивы в него. Кроме того, мы можем решить пойдет ли примитив дальше в растреризатор или нет. Этот же буфер может быть подсоединен как вершинный буфер в следующем цикле отрисовки и дать вершины, которые выходили в предыдущем шаге, на вход. Этот цикл позволяет включить оба шага выше в GPU без вмешательства приложения (не считая подключения соответсвующих буферов и настройки некоторых перменных состояния). Следующая диаграма покажет новую архитектуру конвейера:
</p>
<img src="/images/t28_pipeline.jpg">
<p>
Как много примитивов попадет в буфер transform feedback? что же, если у нас нет GS, то ответ прост - зависит от количества, указанного в функции вызова отрисовки. А если присутствует GS, то количество не известно. Так как GS способен создавать и уничтожать примитивы на ходу (а так же может включать и циклы и ветви), то мы не можем найти итоговое число вершин, окажущихся в буфере. Поэтому, как мы можем рисовать их после, когда мы даже не знаем количество вершин, которое он уже сейчас содержит? Для преодоления этого испытания transform feedback так же включает новый тип вызова отрисовки, который не принимает количество вершин в качестве параметра. Система сама отслеживает их количество за нас для каждого буфера и затем использует это число внутри, когда буфер отправляется на вход. Если мы несколько раз используем буфер transform feedback (добавляя новые вершины), то и их количество вершин будет расти соответственно. Мы так же имеет возможность задать смещение внутри буфера в любой момент, и система автоматически изменит количество вершин.
</p>
<p>
В этом уроке мы будем использовать transform feedback для симуляции эффекта фейерверка. Он относительно просто моделируется с точки зрения математики, поэтому мы сможем сфокусироваться на получении transform feedback. Этот фреймворк может быть использован в дальнейшем для других систем частиц.
</p>
<p>
OpenGL ввел принудительное ограничение, запрещающее использовать один и тот же ресурс для ввода и вывода из цикла отрисовки. Это значит, что если мы захотим обновить частицы в вершином буфере, нам потребуются 2 буфера transform feedback и переключение между ними. В кадре 0 мы будем использовать буфер A и рендерить частицы из буфера B, а в кадре 1 мы обновим частицы в буфере B, а рендерить будем из буфера A. Все будет происходить в тайне от зрителя.
</p>
<p>
Кроме того, мы будем использовать 2 метода - 1 будет направлен для обновления частиц, а другой из рендерить. Мы будем использовать метод billboarding из предыдущего урока для рендера, так что удостоверьтесь, что он еще не забыт.
</p>

<a href="https://github.com/triplepointfive/ogldev/tree/master/tutorial28"><h2>Прямиком к коду!</h2></a>

    
> particle_system.h:29</p>
    
    class ParticleSystem
{
public:
	ParticleSystem();
    
	~ParticleSystem();
    
	bool InitParticleSystem(const Vector3f&amp; Pos);
    
	void Render(int DeltaTimeMillis, const Matrix4f&amp; VP, const Vector3f&amp; CameraPos);
    
private:
    
	bool m_isFirst;
	unsigned int m_currVB;
	unsigned int m_currTFB;
	GLuint m_particleBuffer[2];
	GLuint m_transformFeedback[2];
	PSUpdateTechnique m_updateTechnique;
	BillboardTechnique m_billboardTechnique;
	RandomTexture m_randomTexture;
	Texture* m_pTexture;
	int m_time;
};

<p>
Класс системы частиц инкапсулирует всю механику взаимодействия буферов transform feedback. Один экземпляр этого класса создается приложением и инициализирует в мировых координатах пусковую частицу. В главном цикле рендера будет вызываться функция ParticleSystem::Render() с тремя входящими параметрами: время, прошедшшее с последнего вызова, в милисикундах, произвдение матриц обзора и проекции и позиция камеры в мировом пространстве. Класс так же имеет несколько свойств: индикатор - вызывалась ли уже функция Render(), 2 индекса, которые указывают, какой буфер на данный момент пойдет на вход, а какой на выход, 2 указателя на вершинные буферы, 2 указателя на объекты transform feedback, методы обновления и рендера, текстура, содержащая случайные числа, текстура, которая будет отображаться на частицы и текущее глобальное время.
</p>


    
> particle_system.cpp:31</p>
    
    struct Particle
{
	float Type;    
	Vector3f Pos;
	Vector3f Vel;    
	float LifetimeMillis;    
};

<p>
Каждая частица имеет структуру выше. Частица может быть или пусковой, или снарядом или вторичным снарядом. Пусковая статична и создает другие частицы. Она единственная во всей системе. Пусковая регулярно создает снаряды и запускает их вверх. После нескольких секунд сняряд разрывается на несколько сторичных снарядов, которые летят в случайном направлении. Все частицы, кроме пусковой, имеют время жизни, которое отслеживается системой в милисекундах. Когда время жизни частицы достигнет конца, то частица будет удалена. Каждая частица имеет собственную позицию и скорость. Когда частица создается, то она получает некоторую скорость (вектор). На нее будет влиять гравитация, которая будет направлять частицу вниз. На каждом кадре мы используем скорость для обновления мировых координат частицы. Позиция будет позже использована для рендера частицы.
</p>


    
> particle_system.cpp:67</p>
    
    bool ParticleSystem::InitParticleSystem(const Vector3f&amp; Pos)
{   
	Particle Particles[MAX_PARTICLES];
	ZERO_MEM(Particles);

	Particles[0].Type = PARTICLE_TYPE_LAUNCHER;
	Particles[0].Pos = Pos;
	Particles[0].Vel = Vector3f(0.0f, 0.0001f, 0.0f);
	Particles[0].LifetimeMillis = 0.0f;

	glGenTransformFeedbacks(2, m_transformFeedback);    
	glGenBuffers(2, m_particleBuffer);
    
	for (unsigned int i = 0; i &lt; 2 ; i++) {
		glBindTransformFeedback(GL_TRANSFORM_FEEDBACK, m_transformFeedback[i]);
		glBindBufferBase(GL_TRANSFORM_FEEDBACK_BUFFER, 0, m_particleBuffer[i]);
		glBindTransformFeedback(GL_TRANSFORM_FEEDBACK, 0);
		glBindBuffer(GL_ARRAY_BUFFER, m_particleBuffer[i]);
		glBufferData(GL_ARRAY_BUFFER, sizeof(Particles), Particles, GL_DYNAMIC_DRAW);
	}

<p>
Это первая часть инициализации системы частиц. Мы устанавливаем их хранилище в стек и инициализируем первую частицу как пусковую (остальные частицы будут созданы во время рендера). Ее позиция будет начальной точкой для всех остальных частиц, которые будут созданы, и аналогично для скорости (а пусковая частицы останется статичной). Мы собираемся использовать 2 буфера transform feedback (отрисовка будет происходить в один, в то время как другой пойдет на вход и наоборот), для этого мы создаем 2 объекта transform feedback, используя функцию glGenTransformFeedbacks. Объект transform feedback инкапсулирует все состояния, которые относятся к объекту transform feedback. Мы так же создаем 2 объекта буферов - по одному для каждого объекта transform feedback. Позже мы проделаем для каждого из них одни и те же операции (см. ниже).
</p>
<p>
Начинаем мы с привязывания объекта transform feedback к метке GL_TRANSFORM_FEEDBACK через функцию glBindTransformFeedback(). Это назначит объект "текущим", поэтому следующие операции (относящиеся к transform feedback) будут применены к нему. Затем мы привязываем соответсвующий объект буфера к метке GL_TRANSFORM_FEEDBACK_BUFFER и указываем индекс буфера равным 0. Так мы сделаем этот буфер буфером transform feedback и разместим его в индекс равный 0. Мы можем перенаправлять примитивы более чем в один буфер привязав несколько буферов в различные индексы. Пока что нам нужен только 1. Далее мы привязываем тот же самый объект буфера к GL_ARRAY_BUFFER, что сделает его обычным вершинным буфером и загрузит содержимое массива частиц внутрь. 2 последних вызова в коде выше - обычные указатели на буфер вершин. Итого, мы имеем 2 объекта transform feedback с соответсвующими буферами объектов, которые могут служить и как буферы вершин и как буферы transform feedback.
</p>
<p>
Мы не будем рассматривать остальной код функции InitParticleSystem(), т.к. он не содержит ничего нового. Нам просто требуется инициализировать 2 метода (члены класса ParticleSystem) и назначить некоторые статические параметры, такие как текстура, которая будет наложена на частицы. Смотрите в код для подробностей.
</p>


    
> particle_system.cpp:124</p>
    
    void ParticleSystem::Render(int DeltaTimeMillis, const Matrix4f&amp; VP, const Vector3f&amp; CameraPos)
{
	m_time += DeltaTimeMillis;
    
	UpdateParticles(DeltaTimeMillis);

	RenderParticles(VP, CameraPos);

	m_currVB = m_currTFB;
	m_currTFB = (m_currTFB + 1) &amp; 0x1;
}

<p>
Это главная функция рендера класса ParticleSystem. Она ответственна за обновление глобального счетчика времени и связи между 2 буферами индексов ('m_currVB' - это текущий вершинный буфер и он инициализируется в 0, а 'm_currTFB' - текущий буфер transform feedback т он инициализируется в 1). Главная работа этой функции в вызове 2-х private функций, которые обновляют атрибуты частиц и затем рендерят их. Давайте рассмотрим как обновляются частицы.
</p>


    
> particle_system.cpp:137</p>
    
    void ParticleSystem::UpdateParticles(int DeltaTimeMillis)
{
	m_updateTechnique.Enable();
	m_updateTechnique.SetTime(m_time);
	m_updateTechnique.SetDeltaTimeMillis(DeltaTimeMillis);

	m_randomTexture.Bind(RANDOM_TEXTURE_UNIT);

<p>
Мы начинаем обновление частиц с включения соответствующего метода и устанавливаем некоторые динамические переменные. Этому методу требуется знать время, которое прошло с момента последнего рендера из-за того, что это влияет на расчет движения, и нам требуется глобальное время для зерна случайности. Мы определим GL_TEXTURE3 как модуль текстуры для привязывания случайной текстуры. Случайная текстура используется для обеспечения направления в создании частиц (позже мы увидим как создается такая текстура).
</p>


    				glEnable(GL_RASTERIZER_DISCARD);

<p>
Следующая функция делает то, с чем мы никогда раньше не сталкивались. Так как единственная цель функции отрисовки - обновить буфер transform feedback, то мы предпочтем обрезать примитивы и не допустить их до растеризации. У нас для этого будет использоваться другой вызов. glEnable() с параметром GL_RASTERIZER_DISCARD указывает конвейеру убирать все премитивы, прежде чем они попадут в растеризатор (но после этапа transform feedback). 
</p>


    	glBindBuffer(GL_ARRAY_BUFFER, m_particleBuffer[m_currVB]);    
	glBindTransformFeedback(GL_TRANSFORM_FEEDBACK, m_transformFeedback[m_currTFB]);

<p>
Следующие 2 вызова меняют роли 2 буферов, которые мы создали. 'm_currVB' используется в качестве индекса (или 0 или 1) внутри массива VBs и мы привязываем буфер в этом слоте как вершинный (на вход). 'm_currTFB' используется как индекс (который всегда противоположен 'm_currVB') в массиве объектов transform feedback, и мы привязываем объект в слот transform feedback (которая просит с присоединеным состоянием текущий буфер).
</p>


    	glEnableVertexAttribArray(0);
	glEnableVertexAttribArray(1);
	glEnableVertexAttribArray(2);
	glEnableVertexAttribArray(3);

	glVertexAttribPointer(0,1,GL_FLOAT,GL_FALSE,sizeof(Particle),0);                 // type
	glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,sizeof(Particle),(const GLvoid*)4);  // position
	glVertexAttribPointer(2,3,GL_FLOAT,GL_FALSE,sizeof(Particle),(const GLvoid*)16); // velocity
	glVertexAttribPointer(3,1,GL_FLOAT,GL_FALSE,sizeof(Particle),(const GLvoid*)28); // lifetime

<p>
Мы уже знаем следующие вызовы функций. Они просто устанавливают вершинные атрибуты частиц в вершинный буфер. Позже вы увидите как проверить, что входящий тип соответствует выходящему.
</p>


    	glBeginTransformFeedback(GL_POINTS);

<p>
Настоящее веселье начинается здесь. glBeginTransformFeedback() активирует transform feedback. Все вызовы отрисовки после него, и до вызова glEndTransformFeedback(), перенаправляют их выход в буфер transform feedback согласно текущему привязаному объекту transform feedback. Функция так же принимает топологию. Transform feedback работает так, что только полные примитивы (то есть списки) могут быть записаны в буфер. Это значит, что если вы рисуете 4 вершины в стрипе треугольников или 6 в списке, вы все равно получите 6 вершин (2 треугольника) в буфере feedback. Доступные топологии в этой функции:
</p>
<ul>
<li>GL_POINTS - топология отрисовки должна быть так же GL_POINTS.</li>
li>GL_LINES - в отрисовке могут быть: GL_LINES, GL_LINE_LOOP или GL_LINE_STRIP.</li>
<li>GL_TRIANGLES - для треугольников топологии: GL_TRIANGLES, GL_TRIANGLE_STRIP или GL_TRIANGLE_FAN.</li>
</ul>


    	if (m_isFirst) {
		glDrawArrays(GL_POINTS, 0, 1);
		m_isFirst = false;
	}
	else {
		glDrawTransformFeedback(GL_POINTS, m_transformFeedback[m_currVB]);
	}            


<p>
Как объяснено ранее, мы не можем знать как много частиц выйдет из буфера, но transform feedback готов к этому. Так как мы создаем и уничтожаем частицы относительно пусковой и времени жизни каждой, то мы не можем сказать вызову отрисовки как много частиц обрабатывать. Кроме первого вызова. В этом случае мы знаем, что нащ буфер содержит только пусковую частицу и "система" не имеет данных о предыдущих действиях transform feedback, поэтому он не может самостоятельно сообщить количество частиц. Вот почему первый вызов должен быть задан через стандартную функцию glDrawArrays() с единственной точкой. Остальные вызовы отрисовки будут осуществляться через glDrawTransformFeedback(). Эта функция не нуждается в количестве вершин для обработки. Она просто проверяет входящий буфер и рисует все вершины, которые были в него записаны в пришлый раз (когда он был привязан как буфер transform feedback). Заметим, что когда бы мы не привязали объект transform feedback, количество вершин в буфере станет равным 0 из-за того, что мы вызываем glBindBufferBase() на этот буфер в то время как объект transform feedback изначально привязан (в части инициализации) с параметром смещения равным 0. OpenGL вспомнит, что нам не требуется снова вызывать glBindBufferBase(). Это происходит за кулисами когда объект transform feedback привязан.
</p>
<p>
glDrawTransformFeedback() принимает 2 параметра. Первый - топология. Второй - это объект transform feedback, к которому присоединен текущий буфер вершин. Вспомним, что текущий привязаный объект transform feedback - m_transformFeedback[m_currTFB]. Это метка в функции отрисовки. Число вершин для обработки придет из объекта transform feedback, который был привязан как цель в предыдущем вызове, в проходе по ParticleSystem::UpdateParticles(). Если вы запутались, то просто вспомните, что когда мы рисуем в объект transform feedback #1, мы хотим получить число вершин для отрисовки из transform feedback #0 и наоборот. Сегодня на вход, завтра на выход.
</p>


    		glEndTransformFeedback();

<p>
Каждый вызов glBeginTransformFeedback() должен быть в паре с glEndTransformFeedback(). Если его пропустить, то программа быстро завершится .
</p>


    	glDisableVertexAttribArray(0);
	glDisableVertexAttribArray(1);
	glDisableVertexAttribArray(2);
	glDisableVertexAttribArray(3);
}

<p>
Конец функции стандартный. Когда мы дойдем до этой точки, все вершины будут обновленны. Давайте посмотрим, как рендерить их в новую позицию.
</p>	


    
> particle_system.cpp:177</p>
    
    
void ParticleSystem::RenderParticles(const Matrix4f&amp; VP, const Vector3f&amp; CameraPos)
{
	m_billboardTechnique.Enable();
	m_billboardTechnique.SetCameraPosition(CameraPos);
	m_billboardTechnique.SetVP(VP);
	m_pTexture-&gt;Bind(COLOR_TEXTURE_UNIT);

<p>
Текущий рендер мы начинаем с разрешения метода billboarding и назначение в него параметров. Каждая вершина будет превращена в квадрат и текстура, которую мы привязали, будет на них наложена.
</p>


    	glDisable(GL_RASTERIZER_DISCARD);

<p>
Растеризация была отключена во время записи в буфер feedback. Мы включаем его через отключение GL_RASTERIZER_DISCARD.
</p>


    	glBindBuffer(GL_ARRAY_BUFFER, m_particleBuffer[m_currTFB]);

<p>
Когда мы записываем в буфер transform feedback мы привязываем m_transformFeedback[m_currTFB] как объект transform feedback (метка). Этот объект имеет m_particleBuffer[m_currTFB] как присоединеный вершинный буфер. Теперь мы привязываем этот буфер для продоставления входящих вершин для рендера.
</p>


    	glEnableVertexAttribArray(0);

	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Particle), (const GLvoid*)4);  // position

	glDrawTransformFeedback(GL_POINTS, m_transformFeedback[m_currTFB]);

	glDisableVertexAttribArray(0);
}

<p>
Частица в буфере transform feedback имеет 4 атрибута. Для того, что бы рендерить ее нам требуется только позиция, поэтому только она и включена. Удостоверимся, что шаг (расстояние между атрибутами у 2 соседних вершин) установлен в sizeof(Particle) для размещения трех атрибутов, которые мы игнорируем. Если ошибиться в этом, то в результате будет искаженное изображение.
</p>
<p>
Для отрисовки мы снова используем glDrawTransformFeedback(). Второй параметр - объект transform feedback, который является входящим вершнинным буфером. Это объект "знает" как много рисовать вершин.
</p>


    
> ps_update_technique.cpp:151</p>
    
    bool PSUpdateTechnique::Init()
{
	if (!Technique::Init()) {
		return false;
	}

	if (!AddShader(GL_VERTEX_SHADER, pVS)) {
		return false;
	}

	if (!AddShader(GL_GEOMETRY_SHADER, pGS)) {
		return false;
	}

		<b>    const GLchar* Varyings[4];    
	Varyings[0] = "Type1";
	Varyings[1] = "Position1";
	Varyings[2] = "Velocity1";    
	Varyings[3] = "Age1";
    
	glTransformFeedbackVaryings(m_shaderProg, 4, Varyings, GL_INTERLEAVED_ATTRIBS);</b> 

	if (!Finalize()) {
		return false;
	}
    
	m_deltaTimeMillisLocation = GetUniformLocation("gDeltaTimeMillis");
				m_randomTextureLocation = GetUniformLocation("gRandomTexture");
	m_timeLocation = GetUniformLocation("gTime");
	m_launcherLifetimeLocation = GetUniformLocation("gLauncherLifetime");
	m_shellLifetimeLocation = GetUniformLocation("gShellLifetime");
	m_secondaryShellLifetimeLocation = GetUniformLocation("gSecondaryShellLifetime");

	if (m_deltaTimeMillisLocation == INVALID_UNIFORM_LOCATION ||
		m_timeLocation == INVALID_UNIFORM_LOCATION ||
		m_randomTextureLocation == INVALID_UNIFORM_LOCATION) {
		m_launcherLifetimeLocation == INVALID_UNIFORM_LOCATION ||
		m_shellLifetimeLocation == INVALID_UNIFORM_LOCATION ||
		m_secondaryShellLifetimeLocation == INVALID_UNIFORM_LOCATION) {
		return false;
	}
    
	return true;
}

<p>
Теперь вы поняли механизм создания объекта transform feedback, привязывания к нему буфера и рендера в него. Но остаются еще вопросы: что же на самом деле происходит внутри буфера feedback? Это данные вершин? Можем ли мы указать поднабор атрибутов и каков у них порядок? Ответ в коде выше, выделенным жирным. Эта функция инициализирует PSUpdateTechnique, который и обновляет частицы. Мы используем его без пары glBeginTransformFeedback() и glEndTransformFeedback(). Для указания атрибутов, которые попадут в буфер, мы вызываем glTransformFeedbackVaryings() <b>до линковки программы</b>. Эта функция принимает 4 параметра: указатель на программу, массив строк с названиями атрибутов, количество строк в массиве и или GL_INTERLEAVED_ATTRIBS или GL_SEPARATE_ATTRIBS. Строки в массиве должны содержать имена выходящих атрибутов из последнего шейдера перед FS (или VS или GS). Когда transform feedback включен, эти атрибуты будут записаны в буфер по-вершинно. Порядок будет соответвовать порядку в массиве. Последный параметр в glTransformFeedbackVaryings() сообщает OpenGL записывать все атрибуты как единую структуру в единый буфер (GL_INTERLEAVED_ATTRIBS). Или каждому атрибуту по своему буферу (GL_SEPARATE_ATTRIBS). Если вы используете GL_INTERLEAVED_ATTRIBS, то вы сможете привязать только 1 буфер transform feedback (как мы и сделали). Если вы используете GL_SEPARATE_ATTRIBS, то потребуется привязать различные буферы в каждый слот (согласно количеству вершин). Вспомним, что слот указывается во втором параметре в glBindBufferBase(). Кроме того, вы ограничены GL_MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS - количество слотов для атрибутов (обычно 4).
</p>
<p>
Инициализация всего, кроме glTransformFeedbackVaryings(), ничем не отличается. Но заметим, что FS отсутствует. Так как мы отключили растеризацию во время обновления частиц, то FS нам не нужен...
</p>


    
> ps_update_technique.cpp:21</p>
    
    
#version 330 

layout (location = 0) in float Type;
layout (location = 1) in vec3 Position;
layout (location = 2) in vec3 Velocity;
layout (location = 3) in float Age;

out float Type0;
out vec3 Position0;
out vec3 Velocity0;
out float Age0;

void main()
{
	Type0 = Type;
	Position0 = Position;
	Velocity0 = Velocity;
	Age0 = Age;
}

<p>
Это VS метода обновления частиц, и как вы видите - он очень прост. Все что он делает - передает вершины в GS (где и происходят настоящие действия).
</p>


    
> ps_update_technique.cpp:43</p>
    
    #version 330

layout(points) in;
layout(points) out;
layout(max_vertices = 30) out;

in float Type0[];
in vec3 Position0[];
in vec3 Velocity0[];
in float Age0[];

out float Type1;
out vec3 Position1;
out vec3 Velocity1;
out float Age1;

uniform float gDeltaTimeMillis;
uniform float gTime;
uniform sampler1D gRandomTexture;
uniform float gLauncherLifetime;
uniform float gShellLifetime;
uniform float gSecondaryShellLifetime;

#define PARTICLE_TYPE_LAUNCHER 0.0f
#define PARTICLE_TYPE_SHELL 1.0f
#define PARTICLE_TYPE_SECONDARY_SHELL 2.0f

<p>
Это начало GS в методе обновления частиц содержит все объявления и определения, которые нам понадобятся. Мы собираемся получить на вход точки и отправить их же на выход. Все атрибуты мы получим из VS, они же и выйдут в буфер transform feedback buffer (после некоторой обработки). У нас несколько uniform-переменных, и мы так же разрешаем приложению настроить частоту пусковой частицы и время жизни снаряда и вторичного снаряда (пусковая создает 1 снаряд согласно своей частоте, и снаряд разрывается на вторичные после истечения его срока жизни).
</p>


    vec3 GetRandomDir(float TexCoord){
	vec3 Dir = texture(gRandomTexture, TexCoord).xyz;
	Dir -= vec3(0.5, 0.5, 0.5);
	return Dir;
}                                                                                 

<p>
Это вспомогательная функция, которую мы будем использовать для генерации случайного направления снаряда. Оно записывается в текстуру 1D, элементы которой - 3D векторы (вещевственные). Позже мы увидим, как заполнить текстуру случайными векторами. Это функция просто принимает значение вещевственного числа и берет сэмпл из текстуры. Так как все значения в текстуре в отрезке [0.0-1.0], мы вычитаем этот вектор (0.5,0.5,0.5) из сэмпла для того, что бы переместить значения в отрезок [-0.5 - 0.5]. Это позволит летатть частицам во всех направлениях.
</p>


    void main(){
	float Age = Age0[0] + gDeltaTimeMillis;

	if (Type0[0] == PARTICLE_TYPE_LAUNCHER) {
		if (Age &gt;= gLauncherLifetime) {
			Type1 = PARTICLE_TYPE_SHELL;
			Position1 = Position0[0];
			vec3 Dir = GetRandomDir(gTime/1000.0);
			Dir.y = max(Dir.y, 0.5);
			Velocity1 = normalize(Dir) / 20.0;
			Age1 = 0.0;
			EmitVertex();
			EndPrimitive();
			Age = 0.0;
		}

		Type1 = PARTICLE_TYPE_LAUNCHER;
		Position1 = Position0[0];
		Velocity1 = Velocity0[0];
		Age1 = Age;
		EmitVertex();
		EndPrimitive();
	}

<p>
Главная функция GS обрабатывает частицы. Мы начинаем с обновления возраста частиц и затем действуем согласно их типу. Код выше содержит случай пусковой частицы. Если настало ее время, то мы генерируем частицу снаряда и размещаем ее в буфер transform feedback. Снаряд получает позицию пусковой частицы как начальную точку и случайное направление из случайной текстуры. Мы используем глобальное время как псевдо случайное зерно (не по-настоящему случайное, но нам и такого хватит). Мы устанавливаем минимум значения Y равным 0.5, тем самым снаряд направлен куда-то в небо. Вектор направления нормируется и делется на 20 для вектора скорости (для вашей системы позможно потребутеся отрегулировать значение). Возраст новой частицы конечно же 0 и мы так же обнуляем возраст пусковой частицы для обновления процесса. Кроме того, мы всегда выводит пусковую частицу (иначе мы не сможем создать больше частиц).
</p>


    	else {
		float DeltaTimeSecs = gDeltaTimeMillis / 1000.0f;
		float t1 = Age0[0] / 1000.0;
		float t2 = Age / 1000.0;
		vec3 DeltaP = DeltaTimeSecs * Velocity0[0];
		vec3 DeltaV = vec3(DeltaTimeSecs) * (0.0, -9.81, 0.0);

<p>
Прежде чем обрабатывать снаряд и вторичный снаряд, мы устанавливаем некоторые общие параметры. Разница времени переводится из милисекунд в секунды. Мы изменяем возраст частицы (t1) на новый возраст (t2). Изменения позиции вычисляются согласно формуле "позиция = время * скорость". Наконец, мы вычисляем изменения скорости через умножение разницы времени на вектор гравитации. При рождении частица получает вектор скорости, но затем получает влияния только гравитации (игнорируя ветер и прочее). Скорость падания тела на земле увеличивается на 9.81 метр в секунду. Так как направление задано вниз, то мы получим отрицательный Y и ноль у X и Z. Мы немного упростили вычисления, но в целом эфект не изменился.
</p>


    		if (Type0[0] == PARTICLE_TYPE_SHELL){
			if (Age &lt; gShellLifetime){
				Type1 = PARTICLE_TYPE_SHELL;
				Position1 = Position0[0] + DeltaP;
				Velocity1 = Velocity0[0] + DeltaV;
				Age1 = Age;
				EmitVertex();
				EndPrimitive();
			}
			else{
				for (int i = 0 ; i &lt; 10 ; i++){
					Type1 = PARTICLE_TYPE_SECONDARY_SHELL;
					Position1 = Position0[0];
					vec3 Dir = GetRandomDir((gTime + i)/1000.0);
					Velocity1 = normalize(Dir) / 20.0;
					Age1 = 0.0f;
					EmitVertex();
					EndPrimitive();
				}
			}
		}

<p>
Теперь позаботимся об снаряде. До тех пор, пока время жизни этой частицы не достигло предела, установленного в программе, она остается в системе, и мы только обновляем ее позицию и скорость согласно разнице во времени, которую мы уже вычислили. Как только частица достигнет конца времени жизни, ее уничтожают, и мы создаем 10 вторичных частиц и записываем их в буфер. Они все получат позицию родительской, но для каждой будет случайный вектор скорости. В случае вторичного снаряда мы не ограничиваем направления, поэтому взрыв будет выглядеть реальным.
</p>


    
		else{
			if (Age &lt; gSecondaryShellLifetime){
				Type1 = PARTICLE_TYPE_SECONDARY_SHELL;
				Position1 = Position0[0] + DeltaP;
				Velocity1 = Velocity0[0] + DeltaV;
				Age1 = Age;
				EmitVertex();
				EndPrimitive();
			}
		}
	}
}

<p>Обработка вторичного снаряда схожа с обычным, только в случае достижения конца срока жизни мы не создаем новых частиц, а просто удаляем ее.
</p>


    
> random_texture.cpp:37</p>
    
    bool RandomTexture::InitRandomTexture(unsigned int Size){
	Vector3f* pRandomData = new Vector3f[Size];

	for (unsigned int i = 0 ; i &lt; Size ; i++) {
		pRandomData[i].x = RandomFloat();
		pRandomData[i].y = RandomFloat();
		pRandomData[i].z = RandomFloat();
	}
        
	glGenTextures(1, &amp;m_textureObj);
	glBindTexture(GL_TEXTURE_1D, m_textureObj);
	glTexImage1D(GL_TEXTURE_1D, 0, GL_RGB, Size, 0.0f, GL_RGB, GL_FLOAT, pRandomData);
	glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
				glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_REPEAT);    
        
	delete [] pRandomData;
    
	return GLCheckError();
}

<p>
Класс RandomTexture очень удобен для обеспечения случайных данных в шейдере. Это 1D текстура с внутреннем параметром GL_RGB и вещевтсвенным типом данных. Это значит, что каждый элемент - вектор из 3 вещевтсвенных чисел. Заметим, что мы указываем мод GL_REPEAT. Это позволит нам использовать любые координаты текстуры для доступа к ней. Если координата текстуры больше 1.0, то она просто перенесется в начало, поэтому мы всегда будем получать коректные значения. В этой серии уроков модуль текстуры 3 будет определен для случайной текстуры. Вы можете увидеть установку модулей текстуры в заголовке engine_common.h.
</p>
 