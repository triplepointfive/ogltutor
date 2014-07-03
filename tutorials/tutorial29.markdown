---
title: Урок 29 - 3D Выбор
---


<p>
Возможность сопоставить щелчок мыши в окне с 3D сценой с примитивом (пусть это будет треугольник), которому повезло спроецироваться в ту же точку, в которой был щелчок мыши, называется <i>3D Выбор (Picking)</i>. Это может быть полезно в случаях, когда приложению требуется отобразить пользовательский щелчок мыши (который по своей природе из 2D) на что-либо в локальном / мировом пространстве объекта на сцене. Например, вы можете использовать это для выбора объекта или его части для будущих операций (удаление и прочие). В демо к этому уроку мы рендерим набор объектов и показываем как отметить "выбраный" треугольник красным что бы он выделялся.
</p>
<p>
Для реализации 3D выбора мы воспользуемся способностью OpenGL, которая была представлена в уроке по карте теней (#23) - объект буфера кадров (Framebuffer Object (FBO)). Ранее мы использовали FBO только для буфера глубины, поскольку нам было интересно только сравнивать глубину пикселя из разных позиций. Для  3D выбора мы будем использовать и буфер глубины и буфер цвета для хранения индекса отрисованного треугольника.
</p>
<p>
Секрет 3D выбора очень прост. Мы будем привязывать индекс каждому треугольнику и получать из FS индекс треугольника, на котором находится пиксель. В конечном итоге мы получим буфер "цвета", который содержет не совсем цвет. Для каждого пикселя, который будет покрыт примитивом, мы получим индекс этого примитива. Во время клика мыши в окне мы будем считывать этот индекс обратно (согласно позиции мыши) и рендерить выбраный треугольник красным. С помощью комбинации с буфером глубины во время прохода, мы будем гарантировать, что когда несколько примитивов покрывают одинаковый пиксель, то мы получим индекс самого верхнего примитива (ближайшего к камере).
</p>
<p>
Это, в двух словах, и есть 3D выбор. Прежде чем погрузиться в код, нам потребуется решить несколько простых вопросов. Например, как поступать со множеством объектов? Что делать с многочисленными вызовами отрисовки? Хотим ли мы увеличивать индекс примитивов от объекта к объекту так, что бы каждый примитив в сцене получал уникальный индекс, или начинать заново для каждого объекта?
</p>
<p>
Код в этом уроке исполняет только основную задачу, которая может быть упрощена при необходимости. Мы будем рендерить по три индекса для каждого пикселя:
</p>
<ol>
<li>Индекс объекта, которому принадлежит пиксель. Каждый объект сцены будет иметь уникальный индекс.</li>
<li>Индекс вызова отрисовки внутри объекта. Этот индекс будет обнуляться вначале нового объекта.</li>
<li>Индекс примитива внутри вызова отрисовки. Этот индекс будет обнуляться вначале каждого вызова отрисовки.</li>
</ol>
<p>
Когда мы будем считывать пиксель из буфера, то получим сразу всю троицу. Затем потребуется перейти обратно к конкретному примитиву.
</p>
<p>
Нам потребуется рендерить сцену дважды. Первый проход называется "текстура выбора", которая будет содержать индексы примитивов, и второй проход в обычный буфер цвета. Поэтому главный цикл рендера будет состоять из фазы выбора и фазы рендера.
</p>
<p>
<small>Замечание: модель паука, которая используется в демо, взята из <a href="http://assimp.sourceforge.net/main_downloads.html"> набора исходников Assimp</a>. Она содержит несколько VB, которые позволяют протестировать наш случай.</small>
</p>

<a href="https://github.com/triplepointfive/ogldev/tree/master/tutorial29"><h2>Прямиком к коду!</h2></a>

    
> picking_texture.h:23</p>
    
    class PickingTexture
{
public:
	PickingTexture();

	~PickingTexture();

	bool Init(unsigned int WindowWidth, unsigned int WindowHeight);

	void EnableWriting();
    
	void DisableWriting();
    
	struct PixelInfo {
		tunsigned int ObjectID;
		tunsigned int DrawID;
		tunsigned int PrimID;
        
		PixelInfo() 
		{
			ObjectID = 0;
			DrawID = 0;
			PrimID = 0;
		}
	};

	PixelInfo ReadPixel(unsigned int x, unsigned int y);

private:
	GLuint m_fbo;
	GLuint m_pickingTexture;
	GLuint m_depthTexture;
};

<p>
Класс PickingTexture представляет FBO, в который мы будем рендерить примитивы. Он инкапсулирует указатель на объект буфера кадров, объект текстуры для записи индексов и объект текстуры для буфера глубины. Он инициализируется с теми же параметрами, что и у нашего главного окна, и представляет 3 функции. EnableWriting() должна быть вызвана вначале фазы выбора. Затем мы рендерим все требуемый объекты. В конце мы вызываем DisableWriting() для возврата к стандартному буферу кадра. Для чтения обратно индекса пикселя мы вызываем ReadPixel() и его экранными координатами. Эта функция возвращает структуру с тремя индексами (или индивидуальными номерами (ID)), которые были разобраны в разделе теории. Если мышь кликнула мимо всех объектов, то все поля PrimID структуры PixelInfo будут содержать 0xFFFFFFFF. 
</p>


    
> picking_texture.cpp:48</p>
    
    bool PickingTexture::Init(unsigned int WindowWidth, unsigned int WindowHeight)
{
	// Создание FBO
	glGenFramebuffers(1, &amp;m_fbo);    
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_fbo);

	// Создание объекта текстуры для буфера с информацией о примитиве
	glGenTextures(1, &amp;m_pickingTexture);
	glBindTexture(GL_TEXTURE_2D, m_pickingTexture);
	glTexImage2D(GL_TEXTURE_2D, 0, <b>GL_RGB32UI</b>, WindowWidth, WindowHeight, 
			0, <b>GL_RGB_INTEGER, GL_UNSIGNED_INT</b>, NULL);
	glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, 
				m_pickingTexture, 0);    

	// Создание объекта текстуры для буфера глубины
	glGenTextures(1, &amp;m_depthTexture);
	glBindTexture(GL_TEXTURE_2D, m_depthTexture);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, WindowWidth, WindowHeight, 
				0, GL_DEPTH_COMPONENT, GL_FLOAT, NULL);
	glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, 
				m_depthTexture, 0);    

	// Проверка FBO на корректность
	GLenum Status = glCheckFramebufferStatus(GL_FRAMEBUFFER);

	if (Status != GL_FRAMEBUFFER_COMPLETE) {
		tprintf("FB error, status: 0x%x\n", Status);
		treturn false;
	}
    
	// Возвращаем стандартный буфер кадра
	glBindTexture(GL_TEXTURE_2D, 0);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	return GLCheckError();
}	

<p>
Код выше иницализирует класс PickingTexture. Мы создаем FBO и привязываем его к метке GL_DRAW_FRAMEBUFFER (так как мы собираемся рисовать в него). Затем мы генерируем 2 объекта текстуры (для информации о пикселе и глубине). Заметим, что внутренний формат текстуры, которая будет содержать информацию о пикселе, - GL_RGB32UI. Это означает, что каждый пиксель - вектор из 3-х беззнаковых целочисленных переменных. Этот выбор позволяет нам дойти до 4-х миллиардов объектов, вызовов отрисовки и примитивов (должно хватить большинству сцен...). Кроме того, не смотря на то, что мы инициализируем эту текстуру без данных (последний параметр glTexImage2D - NULL), нам по-прежнему требуется указать соответствующий формат и тип (7-й и 8-й параметры). Формат и тип, который соответствуют GL_RGB32UI - GL_RGB_INTEGER и GL_UNSIGNED_INT. Наконец, мы привязываем эту текстуру к метке GL_COLOR_ATTACHMENT0 у FBO. Так мы обозначаем куда будут выходить данные из фрагментного шейдера.
</p>
<p>
Объект текстуры для буфера глубины создается и привязывается тем же образом, что и в уроке по карте теней, поэтому мы не рассматриваем его снова. После того, как все инициализировано, мы проверяем статус FBO и возвращаем стандартный буфер перед выходом.
</p>


    
> picking_texture.cpp:82</p>
    
    void PickingTexture::EnableWriting()
{
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_fbo);
}

<p>
Прежде чем мы начнем рендерить в текстуру выбора, нам требуется включить ее для записи. Это означает привязать FBO к GL_DRAW_FRAMEBUFFER.
</p>


    
> picking_texture.cpp:88</p>
    
    void PickingTexture::DisableWriting()
{
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
}

<p>
После того, как мы завершим рендерить в текстуру выбора, мы сообщаем OpenGL, что начиная с этого момента мы хотим рендерить в стандартный буфер кадра, передав 0 в метку GL_DRAW_FRAMEBUFFER.
</p>
    PickingTexture::PixelInfo PickingTexture::ReadPixel(unsigned int x, unsigned int y)
{
	glBindFramebuffer(GL_READ_FRAMEBUFFER, m_fbo);
	glReadBuffer(GL_COLOR_ATTACHMENT0);

	PixelInfo Pixel;
	glReadPixels(x, y, 1, 1, GL_RGB_INTEGER, GL_UNSIGNED_INT, &amp;Pixel);
  
	glReadBuffer(GL_NONE);
	glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
    
	return Pixel;
}

<p>
Эта функция принимает координаты на экране и возвращает соответствующий тексель из текстуры выбора. Этот тексель является 3-вектором 32-битной целочисленной переменной, которая содержится в структуре PixelInfo. Для чтения из FBO мы должны сначало привязать его к метке GL_READ_FRAMEBUFFER. Затем нам требуется указать из какого буфера считывать через функцию glReadBuffer(). Причина в том, что FBO может содержать несколько буферов цвета (в которые FS может рендерить по-отдельности), но мы можем только считывать из одного буфера в один момент. Функция glReadPixels и производит соответсвующее чтение. Она принимает прямоугольник, который указывается через левый нижний угол (первая пара параметров) и его ширину / высоту (вторая пара) и считавает результат в адрес, который передан последним параметром. Прямоугольник в нашем случае размером с один тексель. Нам так же требуется сообщить этой функции формат и тип данных из-за того, для некоторых внутренних форматов (таких как знаковая / беззнаковая фиксированная точка) функция способна перевести внутренний формат в другой. В нашем случае мы хотим получить не обработанные данные, поэтому и используем GL_RGB_INTEGER как формат и GL_UNSIGNED_INT как тип. После того, как мы завершили, нам требуется сбросить буфер для чтения и буфер кадра.
</p>


    
> picking_technique.cpp:22</p>
    
    #version 410

layout (location = 0) in vec3 Position;

uniform mat4 gWVP;

void main()
{
	gl_Position = gWVP * vec4(Position, 1.0);
}	

<p>
Это VS класса PickingTechnique. Этот метод отвечает за рендер пикселя в объект PickingTexture. Как вы видите, он очень прост, так как нам требуется только преобразовать позицию вершины.
</p>


    
> picking_technique.cpp:35</p>
    
    #version 410

#extension GL_EXT_gpu_shader4 : enable 

out uvec3 FragColor;

uniform uint gDrawIndex; 
uniform uint gObjectIndex;   

void main()
{
	FragColor = uvec3(gObjectIndex, gDrawIndex, gl_PrimitiveID + 1);
}

<p>
FS класса PickingTechnique записывает информацию о пикселе в текстуру выбора. Индекс объекта и индекс отрисовки совпадает для всех пикселей (в одном вызове), поэтому они поступают из uniform-переменных. Для того, что бы получить индекс примитива мы используем встроенную переменную gl_PrimitiveID. Это индекс примитива, который автоматически поступает из системы. Заметим, что расширение GL_EXT_gpu_shader4 должно быть включено в начале шейдера для его использования. gl_PrimitiveID может быть использована только для GS PS. Если GS включен, и FS хочет использовать gl_PrimitiveID, то GS должен записывать gl_PrimitiveID в одну из выходных переменных, и FS должен объявить ее с аналогичным именем на вход. В нашем случае GS отсутствует, поэтому мы можем просто использовать gl_PrimitiveID.
</p>
<p>
Система устанавливает gl_PrimitiveID в 0 в начале отрисовки. Это усложнит выбор между "фоновыми" пикселями и пикселями, которые покрыты объектами (как разобраться в такой ситуации?). Для исправления этого мы увеличиваем индекс на 1 перед записью на выход. Это значит, что фоновый пиксель может быть отличен, поскольку из индекс равен 0, а к пикселей, покрытых объектами, индекс начинается с 1, как и ID примитива. Мы увидим позже что компенсирует это когда мы будем использовать ID примитива для рендера указаного треугольника.
</p>


    
> render_callbacks.h:21</p>
    
    class IRenderCallbacks
{
public:
	virtual void DrawStartCB(unsigned int DrawIndex) = 0;
};

<p>
Метод выбора требует от приложения обновлять индекс отрисовки перед каждым ее вызовом. Это создает проблему, поскольку текущий класс меша (в случае меша с несколькими VB) внутри проходит по буферам и посылает отдельные вызовы отрисовки для комбинации IB/VB. Это не дает нам шанса для обновления индекса отрисовки. Решение, которое мы применим здесь, это интерфейс выше. Класс PickingTechnique происходит от него и наследует методы выше. Функция Mesh::Render() теперь принимает указатель на этот интерфейс и вызывает только функцию в нем перед началом новой отрисовки. Это обеспечивает прекрасное разделение между классом Mesh и любым методом, который хочет получить обратный вызов перед отрисовкой.
</p>


    
> mesh.cpp:201</p>
    
    void Mesh::Render(<b>IRenderCallbacks* pRenderCallbacks</b>)
{
	...
		
	for (unsigned int i = 0 ; i &lt; m_Entries.size() ; i++) {

				...

		<b>if (pRenderCallbacks) {
			pRenderCallbacks-&gt;DrawStartCB(i);
		}</b>
    
		glDrawElements(GL_TRIANGLES, m_Entries[i].NumIndices, GL_UNSIGNED_INT, 0);
	}

	...
}

<p>
Код выше показывает часть обновленной функции Mesh::Render() с выделеным жирным новым кодом. Если мы не заинтересованны в обратном вызове для каждой отрисовки, мы просто передаем NULL как аргумент функции.
</p>


    
> picking_technique.cpp:93</p>
    
    void PickingTechnique::DrawStartCB(unsigned int DrawIndex)
{
	glUniform1ui(m_drawIndexLocation, DrawIndex);
}	

<p>
Это реализация IRenderCallbacks::DrawStartCB() от класса PickingTechnique. Функция Mesh::Render() предоставляет индекс отрисовки, который передается как uniform-переменная. Заметим, что PickingTechnique так же имеет функцию для установки индекса объекта, но она вызывается напрямую главным приложением без механизма выше.
</p>


    
> tutorial29.cpp:107</p>
    
    virtual void RenderSceneCB()
{
	m_pGameCamera-&gt;OnRender();        

	PickingPhase();
	RenderPhase();
           
	glutSwapBuffers();
}

<p>
Это главная функция рендера. Функционал был разделен на 2 центральных фазы, одна для отрисовки в текстуру выбора, и другая для рендера объектов и обработки щелчка мыши.
</p>


    
> tutorial29.cpp:118</p>
    
    void PickingPhase()
{
	Pipeline p;
	p.Scale(0.1f, 0.1f, 0.1f);
	p.SetCamera(m_pGameCamera-&gt;GetPos(), m_pGameCamera-&gt;GetTarget(), m_pGameCamera-&gt;GetUp());
	p.SetPerspectiveProj(m_persProjInfo);

	m_pickingTexture.EnableWriting();
    
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
	m_pickingEffect.Enable();
    
	for (unsigned int i = 0 ; i &lt; ARRAY_SIZE_IN_ELEMENTS(m_worldPos) ; i++) {
	tp.WorldPos(m_worldPos[i]);
	tm_pickingEffect.SetObjectIndex(i);
	tm_pickingEffect.SetWVP(p.GetWVPTrans());    
	tm_pMesh-&gt;Render(&amp;m_pickingEffect);
	}
    
	m_pickingTexture.DisableWriting();        
}
	
<p>
Фаза выбора начинается с установки объектов Pipeline стандартным способом. Затем мы включаем текстуру выбора для записи и очищаем буферы цвета и глубины. glClear() работает с текущим буфером кадра - в нашем случае текстура выбора. Массив 'm_worldPos' содержит мировые координаты двух объектов, которые рендерятся в демо (оба используют один и тот же меш для простоты). Мы проходим по массиву, устанавливаем позицию в конвейер одну за другой и рендерем объект. Для каждой итерации мы так же обновляем индекс объекта внутри метода выбора. Заметим как функция Mesh::Render() принимает адрес объекта метода выбора в качестве параметра. Это позволяет попасть обратно в метод перед каждым вызовом отрисовки. Прежде чем выйти мы отключаем запись в текстуру выбора, которая записана в стандартный буфер.
</p>


    
> tutorial29.cpp:118</p>
    
    void RenderPhase()
{
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
	Pipeline p;
	p.Scale(0.1f, 0.1f, 0.1f);
	p.SetCamera(m_pGameCamera-&gt;GetPos(), m_pGameCamera-&gt;GetTarget(), m_pGameCamera-&gt;GetUp());
	p.SetPerspectiveProj(m_persProjInfo);
    
	// Если мышь кликнула, то проверяем попадает ли она на треугольник. В этом случае цвет красный.
    
	if (m_leftMouseButton.IsPressed) {
		<b>PickingTexture::PixelInfo Pixel = m_pickingTexture.ReadPixel(m_leftMouseButton.x, 				
							WINDOW_HEIGHT - m_leftMouseButton.y - 1);</b>

		if (<b>Pixel.PrimID != 0</b>) {
			m_simpleColorEffect.Enable();
			p.WorldPos(m_worldPos[Pixel.ObjectID]);
			m_simpleColorEffect.SetWVP(p.GetWVPTrans());
			// Must compensate for the decrement in the FS!
			m_pMesh-&gt;Render(Pixel.DrawID, <b>Pixel.PrimID - 1</b>);
		}
	}
    
	// Рендерим объекты как обычно
	m_lightingEffect.Enable();
	m_lightingEffect.SetEyeWorldPos(m_pGameCamera-&gt;GetPos());
    
	for (unsigned int i = 0 ; i &lt; ARRAY_SIZE_IN_ELEMENTS(m_worldPos) ; i++) {
	tp.WorldPos(m_worldPos[i]);
	tm_lightingEffect.SetWVP(p.GetWVPTrans());
	tm_lightingEffect.SetWorldMatrix(p.GetWorldTrans());                
	tm_pMesh-&gt;Render(NULL);
	}        
}

<p>
После фазы выбора идет фаза рендера. Мы настраиваем конвейер так же как и раньше. Затем идет проверка был ли щелчек мыши. Если был, мы используем PickingTexture::ReadPixel() для захвата информации о пиксели. Так как FS увеличивает ID примитива, то у всех фоновых пикселей ID = 0, а у покрытых от 1 и далее. Если пикслель покрыт объектом, мы включаем очень простой метод, который просто возвращает красный цвет из FS. Мы обновляем объект Pipeline с мировой позицией выбраного объекта используя информацию о пикселе. Мы используем новую функцию рендера класса Mesh, которая принимает ID примитива и требует красный примитив (заметим, что мы должны уменьшать ID примитива, так как у класса Mesh отсчет идет от 0). Наконец мы рендерим примитивы как обычно.
</p>


    
> glut_backend.cpp:60</p>
    
    static void MouseCB(int Button, int State, int x, int y)
{
	s_pCallbacks-&gt;MouseCB(Button, State, x, y);
}


static void InitCallbacks()
{
			...
	glutMouseFunc(MouseCB);
}
	
<p>
Этот урок запрашивает у приложения отслеживать клики мыши. Функция glutMouseFunc() занимается этим. Для нее добавилась дополнительная функция обратного вызова в интерфейс ICallbacks (который наследует класс главного приложения). Вы можеье использовать перечисления такие как GLUT_LEFT_BUTTON, GLUT_MIDDLE_BUTTON и GLUT_RIGHT_BUTTON для обработки нажатой кнопки (первый аргумент MouseCB()). Параметр 'State' сообщает была ли клавиша нажата (GLUT_DOWN) или отпущена (GLUT_UP).
</p>