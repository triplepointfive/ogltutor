---
title: Урок 52 - Первый треугольник в Vulkan
date: 2018-08-06 11:56:30 +0300
---

В прошлом уроке мы узнали как очистить окно и нам была представлена пара ключевых концептов Vulkan -
цепочки переключений и буферы команд. Сегодня мы собираем отрендерить наш первый треугольник.
Для этого нам потребуется ввести 4 новых понятия из мира Vulkan - представление изображения,
проход рендера, буфер кадра и пайплайн. Шейдеры тоже необходимы, но так как они выполняют ту же самую роль, как и в OpenGL, я бы не назвал их чем-то новым. Если вы не знакомы с шейдерами, перед продолжением пройдите 4-й урок.

Давайте начнем с самого большого объекта этого урока - _пайплайн_. На самом деле, полное название _графический пайплайн (graphics pipeline)_
так как Vulkan кроме работы с графикой занимается широким спектром вычислений. В целом, вычисления
состоят из большого числа алгоритмов, которые по своей природе не связаны с 3D (они не основываются на том,
как GPU обрабатывает треугольник), но могут быть ускорены за счёт многопоточности GPU. Поэтому Vulkan и
рассматривает как графический пайплайн, так и пайплайн для вычислений. В этом уроке мы собираемся использовать
только графический пайплайн. Его объект имеет массу свойств, с которыми мы знакомы из мира OpenGL.
Разные штуки для обозначения этапов обработки (вершина, геометрия, тесселяция, ...) которые используют
шейдеры; данные по буферам из которых создаются линии и треугольники; этапы обзора и растеризации;
буфер глубины и много другое. Мы не создавали объект графического пайплайна в предыдущих уроках так как
мы ничего не рисовали. В этом уроке нам потребуется это сделать.

Представления изображений - это мета объекты, прослойка между шейдером и конечным ресурсом из которого
происходит чтение или в который происходит запись. Они позволяют ограничивать доступ к ресурсу (например,
мы можем создать представление, имитирующее единственное изображение в массиве) и задавать формат
отображения ресурса.

Проход рендера управляет списком всех ресурсов которые будут использованы, и их зависимостями (например,
когда ресурс из которого происходило чтение, становится ресурсом в который происходит запись).
Буфер кадра работает рука об руку с проходом рендера через создание двух шаговой связи пайплайна с
ресурсом. Проход рендера привязан к буферу команд и содержит индексы буфера кадров. Буфер кадров
отображает эти индексы на представления изображений (а это уже ссылка на сам ресурс).

Вот краткое описание новых объектов. Теперь давайте создадим их и используем для благих дел.

## [Прямиком к коду!](http://ogldev.atspace.co.uk/)

    class OgldevVulkanApp
    {
    public:

        OgldevVulkanApp(const char* pAppName);

        ~OgldevVulkanApp();

        void Init();

        void Run();

    private:

        void CreateSwapChain();
        void CreateCommandBuffer();
        void RecordCommandBuffers();
        void RenderScene();
        void CreateRenderPass();
        void CreateFramebuffer();
        void CreateShaders();
        void CreatePipeline();

        std::string m_appName;
        VulkanWindowControl* m_pWindowControl;
        OgldevVulkanCore m_core;
        std::vector&lt;VkImage&gt; m_images;
        VkSwapchainKHR m_swapChainKHR;
        VkQueue m_queue;
        std::vector&lt;VkCommandBuffer&gt; m_cmdBufs;
        VkCommandPool m_cmdBufPool;
        std::vector&lt;VkImageView&gt; m_views;
        VkRenderPass m_renderPass;
        std::vector&lt;VkFramebuffer&gt; m_fbs;
        VkShaderModule m_vsModule;
        VkShaderModule m_fsModule;
        VkPipeline m_pipeline;
    };

Это обновленный главный класс урока. Мы добавили 4 приватных метода для создания новых объектов и
новые свойства чтобы их там хранить.

Давайте пройдем по изменениям сверху вниз. Первое что нам нужно сделать, это добавить функции для создания новых типов объектов.
Новые функции добавляются к коду предыдущего урока. Мы начнем с создания прохода рендера.

    void OgldevVulkanApp::CreateRenderPass()
    {
        VkAttachmentReference attachRef = {};
        attachRef.attachment = 0;
        attachRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

        VkSubpassDescription subpassDesc = {};
        subpassDesc.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
        subpassDesc.colorAttachmentCount = 1;
        subpassDesc.pColorAttachments = &attachRef;

Для создания прохода рендера нам требуется заполнить структуру VkRenderPassCreateInfo. Это сложная структура, которая
ссылается на несколько подструктур. Самое главное, она указывает на структуру, содержащую приложения и подпроходы.
Приложения - это ресурсы пайплайна, а подпроходы представляют собой серию команд рисования, которые считывают
и пишут в один и тот же набор приложений.

Структура подпрохода содержит набор приложений, которые ему понадобятся. Набор включает цвет, глубину / трафарет
и мультисэмплы. В нашем единственном подпроходе мы указываем, что подпроход привязан к графическому пайплайну
(а не к вычислительному). Затем мы указываем, что у нас будет лишь одно приложение цвета, которым мы будем
рендерить, а так же мы устанавливаем pColorAttachments на дескриптор приложения (в случае нескольких приложений
цвета здесь был бы массив). У нас нет других типов приложений, поэтому мы их не задаем.

Все приложения, на которые может указывать дескриптор подпрохода, содержат структуру VkAttachmentReference. У этой
структуры два свойства. Первое, называемое 'attachment', это индекс в свойстве 'pAttachments' структуры
renderPassCreateInfo ниже. В целом, проход рендера заполняет массив приложений, а все приложения, указанные в
подпроходе, просто индексы в этом массиве. У нас только одно приложение, поэтому его индекс 0. Другое свойство
в структуре VkAttachmentReference это расположение приложения. Оно позволяет указать как приложение будет использовано,
чтобы драйвер мог заранее построить план действий (что хорошо сказывается на производительности). Мы устанавливаем его
целью рендеринга.

Теперь у нас есть дескриптор единственного подпрохода, который указывает на единственное приложение. Теперь мы должны
указать все приложения в проходе рендера как единственный массив. Приложения из подпрохода - это просто индексы
в этом массиве, поэтому сами данные приложений находятся лишь в одном месте.

        VkAttachmentDescription attachDesc = {};
        attachDesc.format = m_core.GetSurfaceFormat().format;
        attachDesc.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
        attachDesc.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
        attachDesc.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        attachDesc.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
        attachDesc.initialLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        attachDesc.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

        VkRenderPassCreateInfo renderPassCreateInfo = {};
        renderPassCreateInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        renderPassCreateInfo.attachmentCount = 1;
        renderPassCreateInfo.pAttachments = &attachDesc;
        renderPassCreateInfo.subpassCount = 1;
        renderPassCreateInfo.pSubpasses = &subpassDesc;

В структуре прохода рендера мы указываем что у нас одно приложение и один подпроход. Мы так же указываем
адреса соответствующих структур с описанием приложения и подпрохода (если бы у нас было больше одной сущности,
то поля 'attachDesc' и 'subpassDesc' были бы массивами структур).

Давайте рассмотрим свойства структуры VkAttachmentDescription:

- **'format'** это просто формат изображения, используемый для приложения. Мы возьмём её из поверхности, которую создаем
    в [уроке 50](tutorial50.html).
- **'loadOp'** указывает сохранять или очищать предыдущее содержимое буферов цвета и глубины (нам старое содержимое
    не нужно, поэтому очищаем).
- **'storeOp'** указывает будет ли контент, который мы создали в проходе рендера, сохранён или уничтожен (мы сохраняем).
- **'stencilLoadOp'/'stencilStoreOp'** аналогично двум полям выше, но для буфера трафарета. Так как мы не используем
    трафарет, то устанавливаем значение в 'да пофиг'.
- **'initialLayout'/'finalLayout'** изображения в Vulkan хранятся во внутреннем слое, который скрыт от нас. Это
    означает, что мы не знаем структуру пикселей изображения в физической памяти. Всё что Vulkan делает, это предлагает
    несколько типов использования изображения (или _слоев_), которые позволяют указать как будет использоваться
    изображение. Затем каждый производитель видеокарт может отображать эти типы в оптимальный для них формат памяти.
    Мы легко можем переводить изображение из одного типа в другой. Свойства 'initialLayout'/'finalLayout'
    указывают в каком слое изображение будет в начале и в конце прохода рендера. В нашем случае, мы начинаем в слое
    "presentable". Этот слой позволяет отображать цепочку изображений на экране.

        VkResult res = vkCreateRenderPass(m_core.GetDevice(), &renderPassCreateInfo, NULL, &m_renderPass);
        CHECK_VULKAN_ERROR("vkCreateRenderPass error %d\n", res);
    }

Наконец, вызов для создания прохода рендера очень простой, он принимает на вход устройство, адрес новой структуры,
аллокатор (в нашем случае NULL), и возвращает указать на объект прохода рендера в последнем параметре.

    void OgldevVulkanApp::CreateSwapChain()
    {
        . . .
        m_images.resize(NumSwapChainImages);
        m_cmdBufs.resize(NumSwapChainImages);
        m_views.resize(NumSwapChainImages);
        . . .
    }

Мы собираемся рассмотреть как создать буфер кадра, но перед этим давайте убедимся, что приложение не упадет.
Для этого изменим размер свойства 'm_views' (вектор представлений изображений) чтобы он совпадал с количеством
изображений и буферов команд. Это нам потребуется в следующей функции. Это единственное изменение в создании
цепочки переключений.

    void OgldevVulkanApp::CreateFramebuffer()
    {
        m_fbs.resize(m_images.size());

Нам нужно подготовить объект буфера кадров для каждого изображения, поэтому наш первый шаг - это изменить размер
вектора буфера кадров, чтобы он совпадал с количеством изображений.

Давайте теперь пройдем по циклу и создадим буферы кадров. Объекты в пайплайне (например, шейдеры) не могут напрямую
обращаться к ресурсам. Промежуточная сущность _представление изображения_ располагается между изображением и чем
угодно, что обращается за ним. Представление изображения содержит в себе подресурсы изображения и мета данные для
доступа. Поэтому, нам требуется создать представление изображения для того, чтобы буфер кадра имел доступ к изображению.
Мы создадим представление для каждого изображения и буфер кадра для каждого представления изображения.

        for (uint i = 0 ; i < m_images.size() ; i++) {
            VkImageViewCreateInfo ViewCreateInfo = {};
            ViewCreateInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            ViewCreateInfo.image = m_images[i];

Мы подготавливаем структуру VkImageViewCreateInfo. Свойство 'image' должно указывать на соответствующую поверхность
изображения.

            ViewCreateInfo.format = m_core.GetSurfaceFormat().format;

Представления изображений позволяют нам получать доступ к изображению используя формат, отличный от формата изображения.
Например, если формат изображения 16 битный, то мы можем использовать его как один канал 16 бит или два канала 8 бит.
На эти комбинации накладывается масса ограничений. Подробнее о них
[здесь](https://www.khronos.org/registry/vulkan/specs/1.0/html/vkspec.html#features-formats-compatibility-classes).

            ViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;

Мы используем тип представления для того, чтобы указать системе как его интерпретировать. В данном случае, остановимся
на обычном 2D.

            ViewCreateInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY;
            ViewCreateInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY;
            ViewCreateInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY;
            ViewCreateInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY;

Свойство 'components' типа VkComponentMapping. Эта структура позволяет отображать каждый компонент пикселя в другой компонент. Например, мы можем
передавать один компонент в несколько других, или изменить тип RGBA на GBAR (если это вообще может быть нужно ...). Макрос
VK_COMPONENT_SWIZZLE_IDENTITY говорит, что компонент отображается как есть.

Изображение может быть сложным. Например, содержать несколько мип-уровней (несколько разрешений у одной и той же картинки) или несколько
срезов массива (array slices) (что позволяет разместить сразу несколько различных текстур в одно изображение). Мы можем использовать свойство
'subresourceRange' для того, чтобы указать ту часть изображения, в которую мы хотим рендерить. У этой структуры пять полей:

            ViewCreateInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;

'aspectMask' указывает какие части изображения (цвет, глубина или трафарет) являются частью представления.

            ViewCreateInfo.subresourceRange.baseMipLevel = 0;
            ViewCreateInfo.subresourceRange.levelCount = 1;

'baseMipLevel' и 'levelCount' указывают подмножество мип-уровней в изображении. Нужно быть осторожными и не выйти за границы настоящего количества
мип-уровней. Так как обязательно будет хотя бы один уровень, вариант выше безопасен.

            ViewCreateInfo.subresourceRange.baseArrayLayer = 0;
            ViewCreateInfo.subresourceRange.layerCount = 1;

Аналогичное делаем и с массивной частью изображения.

            res = vkCreateImageView(m_core.GetDevice(), &ViewCreateInfo, NULL, &m_views[i]);
            CHECK_VULKAN_ERROR("vkCreateImageView error %d\n", res);

Теперь мы можем создать представление изображения и перейти к созданию буфера кадров.

            VkFramebufferCreateInfo fbCreateInfo = {};
            fbCreateInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
            fbCreateInfo.renderPass = m_renderPass;

В разделе спецификации 7.2 сказано: "Буферы кадра и графические пайплайны создаются для конкретных объектов прохода рендера. Они должны быть
использованы с этим объектом прохода рендера или с другим совместимым". Пока что мы не будем рассматривать проблемы совместимости проходов
рендера так как у нас будет использоваться лишь один такой объект. Наш буфер кадра просто указывает на проход рендера, который мы создали ранее.

            fbCreateInfo.attachmentCount = 1;
            fbCreateInfo.pAttachments = &m_views[i];

Буфер кадра может указывать на несколько приложений. Свойства 'attachmentCount' и 'pAttachments' указывают на массив представлений изображений
и его размер. У нас одно приложение.

            fbCreateInfo.width = WINDOW_WIDTH;
            fbCreateInfo.height = WINDOW_HEIGHT;

Понятия не имею почему нам требуется ещё раз указывать ширину и высоту и почему они не берутся из изображения. Я пробовал поиграться
с этими значениями и не увидел никаких отличий в результате. Стоит разобраться с этим получше.

            fbCreateInfo.layers = 1;

Когда у нас будет геометрический шейдер, мы сможем рендерить в многослойный буфер кадра. А пока остановимся на одном слое.

            res = vkCreateFramebuffer(m_core.GetDevice(), &fbCreateInfo, NULL, &m_fbs[i]);
            CHECK_VULKAN_ERROR("vkCreateFramebuffer error %d\n", res);
        }
    }

После создания представления изображения мы создаем указывающий на него объект буфера кадра. Обратим внимание, что и проход рендера и буфер
кадра знают о приложении, но буфер кадра содержит ссылку на сам ресурс (через представление изображения), а проход рендера содержит лишь
индексы в активном буфере кадра.

Наш объект представления изображения теперь готов, и позже мы увидим как его использовать. Следующая вещь которую мы должны сделать это шейдеры.
Я не буду глубоко погружаться в шейдеры так как в [уроке 4](tutorial4.html) мы уже подробно рассмотрели их и их место в пайплайне. Принципиальных
отличий нет, если нужно больше деталей то перечитайте урок ещё раз. Для создания треугольника нам потребуется пара шейдеров - вершинный и
фрагментный. Обычно мы используем вершинный буфер, чтобы передать вершины в шейдер. Без вершинного буфера далеко не уйти, это стандартный способ
передачи модели, сохраненной на диске, в графический пайплайн. Но на данном этапе, где нам нужен лишь один треугольник на экране, мы хотим сделать
как можно проще. Поэтому мы будем использовать вершинный шейдер для генерации 3-х вершин и отправки их по одной по пайплайну, пока их не
интерполирует растеризатор и не запустит для них фрагментный шейдер.

Вот полный код вершинного шейдера:

    #version 400

    void main()
    {
        vec2 pos[3] = vec2[3]( vec2(-0.7, 0.7),
                               vec2(0.7, 0.7),
                               vec2(0.0, -0.7) );
        gl_Position = vec4( pos[gl_VertexIndex], 0.0, 1.0 );
    }

Вершинный шейдер начинается с прагмы, которая устанавливает версию. Весь код шейдера состоит из одной функции _main()_. Шейдер создает массив
из 3-х двумерных векторов и заполняет их координатами вершин треугольника. Мы начинаем с нижнего левого угла и движемся против часовой стрелки
пока не дойдём до верху. Сейчас я не буду объяснять координатную систему, но вы можете попробовать изменить эти значения и посмотреть что
получится.

Даже если мы не планируем привязывать буфер вершин, так как команда отрисовки будет вызвана 3 раза, то и шейдер будет вызван 3 раза. Я полагаю
что это нормально, хотя мы и не используем буфер. Нам нужно для каждого вызова шейдера передавать по одной вершине. Для этого воспользуемся
встроенной переменной gl_VertexIndex. Как вы могли предположить, эта переменная - счётчик, который начинается с 0 и автоматически увеличивается
на 1 при каждом вызове вершинного шейдера. Мы используем её как индекс в массиве координат вершин. Координату Z устанавливаем в 0, а гомогенную
координату W в 1.0. Результат записываем в другую встроенную переменную gl_Position. gl_Position - это выходные данные из шейдера. Они отправляются
в растеризатор, который собирает все 3 вершины и интерполирует фрагмент между ними.

Для того чтобы привязать шейдер в графическому пайплайну нам требуется скомпилировать текстовый шейдер в бинарный. Шейдерный язык в Vulkan
называется SPIR-V и он также предоставляет общую промежуточную форму, аналогичную ассемблеру. Промежуточная форма будет передана в GPU, который
преобразует её в свой собственный набор инструкций. Компилятор находится в Vulkan SDK
**&lt;Vulkan root&gt;/glslang/build/install/bin/glslangValidator**.

Вершинный шейдер компилируется следующим образом:

**glslangValidator -V simple.vert -o vs.spv**

В файле simple.vert сам текст шейдера, а флаг '-o' указывает имя выходного файла. Обратите внимание, что компилятор определяет тип шейдра
по разрешению файла, поэтому для вершинных шейдеров это должен быть 'vert' и 'frag' для фрагментных шейдеров.

Теперь фрагментный шейдер:

    #version 400

    layout(location = 0) out vec4 out_Color;

    void main()
    {
      out_Color = vec4( 0.0, 0.4, 1.0, 1.0 );
    }

Версия и точка входа аналогичны вершинному шейдеру, но фрагментный шейдер отдает на выходе цвет, в отличие от вершинного шейдера, который
возвращает вершину. На выход мы отдаем 4-х мерный вектор, в который записан произвольный цвет. Вот и всё, это весь шейдер. Для компиляции
используем команду:

**glslangValidator -V simple.frag -o fs.spv**

Теперь когда оба шейдера скомпилированны, нам нужно получить указатели на шейдеры, чтобы привязать их к объекту пайплайна. Следующая функция
делает как раз это:

    void OgldevVulkanApp::CreateShaders()
    {
        m_vsModule = VulkanCreateShaderModule(m_core.GetDevice(), "Shaders/vs.spv");
        assert(m_vsModule);

        m_fsModule = VulkanCreateShaderModule(m_core.GetDevice(), "Shaders/fs.spv");
        assert(m_fsModule);
    }

VulkanCreateShaderModule() - это функция-обертка определенная в библиотеке commonVulkan (часть исходников OGLDEV):

    VkShaderModule VulkanCreateShaderModule(VkDevice& device, const char* pFileName)
    {
        int codeSize = 0;
        char* pShaderCode = ReadBinaryFile(pFileName, codeSize);
        assert(pShaderCode);

        VkShaderModuleCreateInfo shaderCreateInfo = {};
        shaderCreateInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        shaderCreateInfo.codeSize = codeSize;
        shaderCreateInfo.pCode = (const uint32_t*)pShaderCode;

        VkShaderModule shaderModule;
        VkResult res = vkCreateShaderModule(device, &shaderCreateInfo, NULL, &shaderModule);
        CHECK_VULKAN_ERROR("vkCreateShaderModule error %d\n", res);
        printf("Created shader %s\n", pFileName);
        return shaderModule;
    }

Эта функция начинается с чтения бинарного файла шейдера. ReadBinaryFile() это вспомогательная функция, которая возвращает указать на строку с
содержимым файла, и его размер. Указатель и размер передаются в структуру VkShaderModuleCreateInfo, а функция vkCreateShaderModule принимает
эту структуру и возвращает указатель на шейдер.

Последний объект, который нам требуется, это графический пайплайн. Он самый сложный, так что пристегнитесь...
Я постарался удалить как можно больше из инициализации этого объекта. У меня работает. Понадеемся, что я не забыл ничего и оно запустится и на
вашей системе.

    void OgldevVulkanApp::CreatePipeline()
    {
        VkPipelineShaderStageCreateInfo shaderStageCreateInfo[2] = {};

        shaderStageCreateInfo[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        shaderStageCreateInfo[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
        shaderStageCreateInfo[0].module = m_vsModule;
        shaderStageCreateInfo[0].pName = "main";
        shaderStageCreateInfo[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        shaderStageCreateInfo[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
        shaderStageCreateInfo[1].module = m_fsModule;
        shaderStageCreateInfo[1].pName = "main";

Функция создания объекта пайплайна принимает несколько входных параметров. Рассмотрим их по одному. Первая структура VkPipelineShaderStageCreateInfo
указывает какие шейдерные этапы включены. В этом уроке у нас только вершинный и фрагментный шейдеры, поэтому нам нужен массив с двумя инстансами.
Для каждого шейдерного этапа мы ставим свой флаг, указатель, который был создан функцией vkCreateShaderModule(), и имя точки входа.

        VkPipelineVertexInputStateCreateInfo vertexInputInfo = {};
        vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

VkPipelineVertexInputStateCreateInfo определяет вершинный буфер, который будет передан в пайплайн. Так как у нас нет буфера, мы просто передаем тип структуры и хватит.

        VkPipelineInputAssemblyStateCreateInfo pipelineIACreateInfo = {};
        pipelineIACreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        pipelineIACreateInfo.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

VkPipelineInputAssemblyStateCreateInfo указывает с какой топологией будет работать пайплайн. Это очень маленькая структура, и нам нужно установить
топологию только для функции отрисовки. Vulkan поддерживает 10 типов топологий, такие как точка, линия, треугольник и прочие. Подробнее
[здесь](https://www.khronos.org/registry/vulkan/specs/1.1/html/vkspec.html#VkPrimitiveTopology).

        VkViewport vp = {};
        vp.x = 0.0f;
        vp.y = 0.0f;
        vp.width  = (float)WINDOW_WIDTH;
        vp.height = (float)WINDOW_HEIGHT;
        vp.minDepth = 0.0f;
        vp.maxDepth = 1.0f;

Структура окна просмотра задает его преобразования, конкретней как нормированы координаты (от -1 до 1 по всем осям). Значения X/Y устанавливаем
равными размеру окна. Глубина определяем минимальное / максимальное значения, которое будет записано в буфер глубины. Установим его от 0 до 1.

        VkPipelineViewportStateCreateInfo vpCreateInfo = {};
        vpCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        vpCreateInfo.viewportCount = 1;
        vpCreateInfo.pViewports = &vp;

Теперь мы можем инициализировать структуру состояния окна просмотра.

        VkPipelineRasterizationStateCreateInfo rastCreateInfo = {};
        rastCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rastCreateInfo.polygonMode = VK_POLYGON_MODE_FILL;
        rastCreateInfo.cullMode = VK_CULL_MODE_BACK_BIT;
        rastCreateInfo.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
        rastCreateInfo.lineWidth = 1.0f;

VkPipelineRasterizationStateCreateInfo управляет различными аспектами растеризации. **polygonMode** переключает между каркасным и полным режимами
(попробуйте изменить на VK_POLYGON_MODE_LINE). **cullMode** определяет отсекать ли переднюю или заднюю стороны треугольника (посмотрите что
получится если изменить на VK_POLYGON_FRONT_BIT). **frontFace**  говорит пайплайну как задан порядок вершин (по часовой или против).

        VkPipelineMultisampleStateCreateInfo pipelineMSCreateInfo = {};
        pipelineMSCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;

Multi-Sampling - это механизм, который улучшает внешний вид линий и сторон полигонов (но также и точек). Он так же известен как Anti-Aliasing.
Хотя мы не используем его, мы должны установить соответствующее состояние в конвейере, так что мы подготовим для него минимальную структуру.

        VkPipelineColorBlendAttachmentState blendAttachState = {};
        blendAttachState.colorWriteMask = 0xf;

Несмотря на то, что мы не используем никакого смешивания, мы должны установить маску записи цвета в структуру смешивания, чтобы разрешить запись
на всех четырех каналах (попробуйте использовать различные комбинациями первых 4 бит). Фактически, эта структура сама по себе не несёт смысла и
должна быть передана в структуру информации о состоянии смешивания, которую мы создадим дальше.

        VkPipelineColorBlendStateCreateInfo blendCreateInfo = {};
        blendCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        blendCreateInfo.logicOp = VK_LOGIC_OP_COPY;
        blendCreateInfo.attachmentCount = 1;
        blendCreateInfo.pAttachments = &blendAttachState;

logicOp определяет какое действие (AND/OR/XOR и другие) будет выполняться над старым и новым содержимым буфера кадров. Так как мы хотим чтобы новое
содержимое перезаписывало старое, то ставим режим копирования.

        VkGraphicsPipelineCreateInfo pipelineInfo = {};
        pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        pipelineInfo.stageCount = ARRAY_SIZE_IN_ELEMENTS(shaderStageCreateInfo);
        pipelineInfo.pStages = &shaderStageCreateInfo[0];
        pipelineInfo.pVertexInputState = &vertexInputInfo;
        pipelineInfo.pInputAssemblyState = &pipelineIACreateInfo;
        pipelineInfo.pViewportState = &vpCreateInfo;
        pipelineInfo.pDepthStencilState = &dsInfo;
        pipelineInfo.pRasterizationState = &rastCreateInfo;
        pipelineInfo.pMultisampleState = &pipelineMSCreateInfo;
        pipelineInfo.pColorBlendState = &blendCreateInfo;
        pipelineInfo.renderPass = m_renderPass;
        pipelineInfo.basePipelineIndex = -1;
        VkResult res = vkCreateGraphicsPipelines(m_core.GetDevice(), VK_NULL_HANDLE, 1, &pipelineInfo, NULL, &m_pipeline);
        CHECK_VULKAN_ERROR("vkCreateGraphicsPipelines error %d\n", res);
    }

Теперь когда у нас все есть, нам нужно создать объект пайплайна. Мы заполняем структуру создания пайплайна указателями на все промежуточные
структуры, которые мы только что создали. Так же передаем проход рендера и отключаем производные пайплайна (pipeline derivatives) (сложная тема)
передав -1 в basePipelineIndex.

Теперь когда мы создали все новые объекты, давайте рассмотрим последнее крупное изменение - запись в командный буфер.

    void OgldevVulkanApp::RecordCommandBuffers()
    {
        VkCommandBufferBeginInfo beginInfo = {};
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        beginInfo.flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT;

        VkClearColorValue clearColor = { 164.0f/256.0f, 30.0f/256.0f, 34.0f/256.0f, 0.0f };
        VkClearValue clearValue = {};
        clearValue.color = clearColor;

        VkImageSubresourceRange imageRange = {};
        imageRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        imageRange.levelCount = 1;
        imageRange.layerCount = 1;

В первых 3-х структурах этой функции никаких изменений.

        VkRenderPassBeginInfo renderPassInfo = {};
        renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        renderPassInfo.renderPass = m_renderPass;
        renderPassInfo.renderArea.offset.x = 0;
        renderPassInfo.renderArea.offset.y = 0;
        renderPassInfo.renderArea.extent.width = WINDOW_WIDTH;
        renderPassInfo.renderArea.extent.height = WINDOW_HEIGHT;
        renderPassInfo.clearValueCount = 1;
        renderPassInfo.pClearValues = &clearValue;

Запись в командный буфер использует проход рендера сообщая драйверу где начинается и заканчивается проход. Начало прохода рендера требует структуру
выше, которая содержит в себе указать на проход рендера и зону рендера. Мы просто устанавливаем её во всё окно (не уверен зачем нам сразу и
зона рендера и окно просмотра). В предыдущем уроке мы начинали командный буфер, записывали команду очистки в него, и завершали буфер. Мы всё ещё
можем так сделать, но есть способ проще. Проход рендера содержит массив структур очистки. Если массив заполнен, это аналогично явной команде
очистки.

        VkViewport viewport = { 0 };
        viewport.height = (float)WINDOW_HEIGHT;
        viewport.width = (float)WINDOW_WIDTH;
        viewport.minDepth = (float)0.0f;
        viewport.maxDepth = (float)1.0f;

        VkRect2D scissor = { 0 };
        scissor.extent.width = WINDOW_WIDTH;
        scissor.extent.height = WINDOW_HEIGHT;
        scissor.offset.x = 0;
        scissor.offset.y = 0;

Мы подготавливаем окно просмотра и структуру обрезания для отображения всего окна.

        for (uint i = 0 ; i < m_cmdBufs.size() ; i++) {
            VkResult res = vkBeginCommandBuffer(m_cmdBufs[i], &beginInfo);
            CHECK_VULKAN_ERROR("vkBeginCommandBuffer error %d\n", res);
            renderPassInfo.framebuffer = m_fbs[i];

Мы переиспользуем информацию начала прохода рендера просто устанавливая указатель на правильный буфер кадра на каждой итерации.

            vkCmdBeginRenderPass(m_cmdBufs[i], &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);

Мы начинаем буфер команд и указываем VK_SUBPASS_CONTENTS_INLINE таким образом, что все записано в первичный буфер команд (пока не будем
использовать второй буфер).

            vkCmdBindPipeline(m_cmdBufs[i], VK_PIPELINE_BIND_POINT_GRAPHICS, m_pipeline);

            vkCmdSetViewport(m_cmdBufs[i], 0, 1, &viewport);

            vkCmdSetScissor(m_cmdBufs[i], 0, 1, &scissor);

Мы привязываем графический пайплайн и устанавливаем окно просмотра и структуру обрезания.

            vkCmdDraw(m_cmdBufs[i], 3, 1, 0, 0);

            vkCmdEndRenderPass(m_cmdBufs[i]);

Наконец, мы записываем команду отрисовки. Аргументы - это буфер команд куда записывать, количество вершин, количество инстансов (для перезапуска
отрисовки с другими шейдерными параметрами), индекс первой вершины для рисования и индекс первого инстанса. На этом с командным буфером все.

            res = vkEndCommandBuffer(m_cmdBufs[i]);
            CHECK_VULKAN_ERROR("vkEndCommandBuffer error %d\n", res);
        }
     }

    void OgldevVulkanApp::Init()
    {
    #ifdef WIN32
        m_pWindowControl = new Win32Control(m_appName.c_str());
    #else
        m_pWindowControl = new XCBControl();
    #endif
        m_pWindowControl->Init(WINDOW_WIDTH, WINDOW_HEIGHT);

        m_core.Init(m_pWindowControl);

        vkGetDeviceQueue(m_core.GetDevice(), m_core.GetQueueFamily(), 0, &m_queue);

        CreateSwapChain();
        CreateCommandBuffer();
        CreateRenderPass();
        CreateFramebuffer();
        CreateShaders();
        CreatePipeline();
        RecordCommandBuffers();
    }

Последнее что нам нужно сделать - это вызвать функции для создания 4 новых объектов.

Вот и наш треугольник:

![](/images/52/tutorial52.jpg)
