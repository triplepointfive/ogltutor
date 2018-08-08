---
title: Урок 52 - Vulkan First Triangle
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
(а не к вычислителному). Затем мы указываем, что у нас будет лишь одно приложение цвета, которым мы будем
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

Наконец, вызод для создания прохода рендера очень простой, он принимает на вход устройство, адрес новой структуры,
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
(здесь)[https://www.khronos.org/registry/vulkan/specs/1.0/html/vkspec.html#features-formats-compatibility-classes].

            ViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;

Мы используем тип представления для того, чтобы указать системе как его интерпретировать. В данном случае, остановимся
на обычном 2D.

            ViewCreateInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY;
            ViewCreateInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY;
            ViewCreateInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY;
            ViewCreateInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY;

Свойтво 'components' типа VkComponentMapping. Эта структура позволяет отображать каждый компонент пикселя в другой компонент. Например, мы можем
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

From section 7.2 of the spec: "Framebuffers and graphics pipelines are created based on a specific render pass object.
They must only be used with that render pass object, or one compatible with it". We are not going to go into the issue of render pass compatibility
since it is only relevant when you have more than one render pass. For now our framebuffer simply points to the render pass we created earlier.

            fbCreateInfo.attachmentCount = 1;
            fbCreateInfo.pAttachments = &m_views[i];

The framebuffer can point to multiple attachments. The 'attachmentCount' and 'pAttachments' members specify an array of image views and
its size. We have a single attachment.

            fbCreateInfo.width = WINDOW_WIDTH;
            fbCreateInfo.height = WINDOW_HEIGHT;

Not sure exactly why we need to re-specify the width and height and why they are not fetched from the image.
I played with the values here and there was no change in the result. Need to investigate this further.

            fbCreateInfo.layers = 1;

When a geometry shader is preset we can render into a multi layer framebuffer. For now, we have a single layer.

            res = vkCreateFramebuffer(m_core.GetDevice(), &fbCreateInfo, NULL, &m_fbs[i]);
            CHECK_VULKAN_ERROR("vkCreateFramebuffer error %d\n", res);
        }
    }

Once the image view has been created we can create a framebuffer object that points to it. Notice that both the render pass
and the framebuffer have a notion of an attachment, but where the framebuffer contains references to the actual resource (via image view),
the render pass only contains indices into the framebuffer which is currently active.
Our framebuffer object is now ready and we will see later how it is used. The next thing we need to create are the shaders. Now I'm not going to go too deeply into the
background about shaders because we covered that in <a href="../tutorial04/tutorial04.html">tutorial #4</a> and the principle idea hasn't changed. Just read that tutorial again
if you need more details. What we need in order to render a triangle are a couple of shaders - a vertex shader and a fragment shader.
Usually you will also use a vertex buffer in order to feed vertices into the vertex shader. You cannot go far without vertex buffers because
they are the standard way of loading models stored on disk into the graphics pipeline. But at this stage where we just want one triangle on the screen
and we want to keep things as simple as possible we can actually use the vertex shader in order to generate three vertices and send them one
by one all the way through the pipeline until the rasterizer interpolates them and executes the fragment shader on each interpolated fragment.

Here's the full vertex shader code:

    #version 400

    void main()
    {
        vec2 pos[3] = vec2[3]( vec2(-0.7, 0.7),
                               vec2(0.7, 0.7),
                               vec2(0.0, -0.7) );
        gl_Position = vec4( pos[gl_VertexIndex], 0.0, 1.0 );
    }

The vertex shader starts by a pragma that sets the version. The shader code itself is contained in a single function called main(). The shader creates
an array of 3 two dimensional vectors and populates them with the coordinates of the triangle. We start at the bottom left and go
in a counter clockwise direction until we reach the top. We are not going into the coordinate system at this time but you can play with
the values and see for yourself.

Even though we are not going to attach a vertex buffer, since the draw command will be executed with a vertex count of 3 the vertex shader will
also execute 3 times. We are not accesing vertices from vertex buffers so I guess this is ok. We now need to send the vertices down the graphics pipeline one by one for each
execution of the vertex shader. We do this using the builtin variable gl_VertexIndex. As you may have guessed, this variable is a counter which is
initialized to zero and automatically incremented by one for each execution of the vertex shader. We use it in order to index into the pos array and grab
the next vertex to send. We set the Z coordinate to zero and the homogenous coordinate W to 1.0. The result is set into another buildin variable called gl_Position.
gl_Position is the output from the vertex shader. It is sent down to the rasterizer which accumulates all three vertices and interpolates the fragments between
them.

In order to connect the shader to the graphics pipeline we must compile the shader text into binary form. The shader languange in Vulkan is called SPIR-V and
it also provides a common intermediate form that is similar to assembly language. This intermediate form will be fed into the driver of your the GPU which will
translate it into its own instruction set. The compiler is located in the Vulkan SDK in <b>&lt;Vulkan root&gt;/glslang/build/install/bin/glslangValidator</b>.

The vertex shader is compiled as follows:

<b>glslangValidator -V simple.vert -o vs.spv</b>

simple.vert contains the shader text and the '-o' option specifies the name of the binary file. Note that the compiler decifers the type of the shader stage
from the extension of the shader text file so we must use 'vert' for vertex shaders and 'frag' for fragment shaders.

Now for the fragment shader:

    #version 400

    layout(location = 0) out vec4 out_Color;

    void main()
    {
      out_Color = vec4( 0.0, 0.4, 1.0, 1.0 );
    }

The version and entry point are the same idea as the vertex shader, but the fragment shader is focused on the output color of the pixel rather
than the location of the vertex. We define the output from the shader as a 4 dimensional color vector and set it to some constant color. That's it. The fragment
shader is compiled using:

<b>glslangValidator -V simple.frag -o fs.spv</b>

Now that both shaders are compiled we need to create a couple of shader handles that will later be attached to the pipeline object. The following function takes
care of that:

    void OgldevVulkanApp::CreateShaders()
    {
        m_vsModule = VulkanCreateShaderModule(m_core.GetDevice(), "Shaders/vs.spv");
        assert(m_vsModule);

        m_fsModule = VulkanCreateShaderModule(m_core.GetDevice(), "Shaders/fs.spv");
        assert(m_fsModule);
    }

VulkanCreateShaderModule() is a wrapper that is defined in the commonVulkan library (which is part of OGLDEV sources) as:

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

This function starts by reading the shader binary file. ReadBinaryFile() is a utility function that returns a pointer
to a char buffer with the file content as well as its size. The pointer and size are set into a VkShaderModuleCreateInfo structure
and the Vulkan function vkCreateShaderModule takes this structure and returns a shader handle.

The final object we need to create is a graphics pipeline object. This is going to be one complex object so hang on...
I tried to remove as much as I could from the initialization of this object. It works for me. Hopefully I didn't leave out
something which will prevent it from running on your system.

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

The pipeline object creation function takes several structures as input parameters. We will review them one by one.
The first structure, VkPipelineShaderStageCreateInfo, specifies the shader stages that are enabled. In this tutorial we only
have the vertex and the fragment shader so we need an array with two instances. For each shader stage we set the shader stage bit,
the handle that we created using vkCreateShaderModule() and the name of the entry point.

        VkPipelineVertexInputStateCreateInfo vertexInputInfo = {};
        vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

VkPipelineVertexInputStateCreateInfo defines the vertex buffers that feed the pipeline. Since we don't have any we just
set the type of the struct and that's it.

        VkPipelineInputAssemblyStateCreateInfo pipelineIACreateInfo = {};
        pipelineIACreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        pipelineIACreateInfo.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

VkPipelineInputAssemblyStateCreateInfo specifies the topology that the pipeline will process. This is a very small struct and
we only need to set the topology for the draw call. Vulkan supports ten types of topologies such as point/line/triangle lists,
topologies with and without adjacencies, etc. See more in <a href="https://www.khronos.org/registry/vulkan/specs/1.1/html/vkspec.html#VkPrimitiveTopology">this link</a>.

        VkViewport vp = {};
        vp.x = 0.0f;
        vp.y = 0.0f;
        vp.width  = (float)WINDOW_WIDTH;
        vp.height = (float)WINDOW_HEIGHT;
        vp.minDepth = 0.0f;
        vp.maxDepth = 1.0f;

The viewport structure defines the viewport transformation, that is, the way the normalized coordinates (-1 to 1 on all axis) will be
translated to screen space. We set the X/Y values according to the size
of the window. The depth range represents the min/max values that will be written to the depth buffer. We set it to go from zero to one.

        VkPipelineViewportStateCreateInfo vpCreateInfo = {};
        vpCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        vpCreateInfo.viewportCount = 1;
        vpCreateInfo.pViewports = &vp;

We can now initialize the viewport state struct with our single viewport.

        VkPipelineRasterizationStateCreateInfo rastCreateInfo = {};
        rastCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rastCreateInfo.polygonMode = VK_POLYGON_MODE_FILL;
        rastCreateInfo.cullMode = VK_CULL_MODE_BACK_BIT;
        rastCreateInfo.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
        rastCreateInfo.lineWidth = 1.0f;

The VkPipelineRasterizationStateCreateInfo controlls various aspects of rasterization. <b>polygonMode</b> toggles between wireframe and
full mode (try changing it to VK_POLYGON_MODE_LINE). <b>cullMode</b> determines whether we cull back or front facing triangles (see what happens
when you change it from VK_POLYGON_FRONT_BIT). <b>frontFace</b> tells
the pipeline how to read the order of our vertices (whether they are spilled out in clockwise or counter clockwise mode).

        VkPipelineMultisampleStateCreateInfo pipelineMSCreateInfo = {};
        pipelineMSCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;

Multi-Sampling is a mechanism that improves the appearance of lines and the edges of polygons (but also points). This is also known as Anti-Aliasing.
While we are not using it we must set the corresponding state in the pipeline so above we prepare a minimal structure for it.

        VkPipelineColorBlendAttachmentState blendAttachState = {};
        blendAttachState.colorWriteMask = 0xf;

Even though we are not using any blending here we must set the color write mask in the blend state structure to enable writing
on all four channels (try playing with various combinations of the bottom 4 bits). Actually, this struct does not stand on its own and must
be pointed to by the color blend state create info struct, which we will create next.

        VkPipelineColorBlendStateCreateInfo blendCreateInfo = {};
        blendCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        blendCreateInfo.logicOp = VK_LOGIC_OP_COPY;
        blendCreateInfo.attachmentCount = 1;
        blendCreateInfo.pAttachments = &blendAttachState;

The logic op determines whether we will AND/OR/XOR/etc the old and new contents of the framebuffer. Since we want the new contents to override the old
we set it to copy.

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

We now have everything we need to create the pipeline object. We update the graphic pipeline create info struct with pointers to all the intermediate
structures that we've just created. We also set the render pass handle and disable pipeline derivatives (an advanced topic) by setting basePipelineIndex to -1.

Now with the four new objects finally created let's take a look at the last major change in this tutorial - recording the command buffers.

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

There is no change in the first three structures of this function.

        VkRenderPassBeginInfo renderPassInfo = {};
        renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        renderPassInfo.renderPass = m_renderPass;
        renderPassInfo.renderArea.offset.x = 0;
        renderPassInfo.renderArea.offset.y = 0;
        renderPassInfo.renderArea.extent.width = WINDOW_WIDTH;
        renderPassInfo.renderArea.extent.height = WINDOW_HEIGHT;
        renderPassInfo.clearValueCount = 1;
        renderPassInfo.pClearValues = &clearValue;

The way that a render pass is used while recording a command buffer is by telling the driver where the
render pass begins and where it ends. Beginning a render pass requires the above structure which contains
the render pass handle and a render area which defines the region where the render pass has an affect. We simply
set it to the entire size of the window (not exactly sure why we need both viewport and render area). In the previous
tutorial we began the command buffer, recorded a clear command into it and ended the command buffer. We can still do that
but there is a simpler way. The render pass begin info contains an array of clear values structures. If that array is
set it is the same as an explicit clear command.

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

We prepare an viewport and scissor that cover the entire extent of the window.

        for (uint i = 0 ; i < m_cmdBufs.size() ; i++) {
            VkResult res = vkBeginCommandBuffer(m_cmdBufs[i], &beginInfo);
            CHECK_VULKAN_ERROR("vkBeginCommandBuffer error %d\n", res);
            renderPassInfo.framebuffer = m_fbs[i];

We reuse the render pass begin info by setting just the handle to the correct framebuffer on each iteration.

            vkCmdBeginRenderPass(m_cmdBufs[i], &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);

We begin the command buffer and specify VK_SUBPASS_CONTENTS_INLINE so that everything is recorded in the primary
command buffer (avoiding the use of secondary command buffers at this time).

            vkCmdBindPipeline(m_cmdBufs[i], VK_PIPELINE_BIND_POINT_GRAPHICS, m_pipeline);

            vkCmdSetViewport(m_cmdBufs[i], 0, 1, &viewport);

            vkCmdSetScissor(m_cmdBufs[i], 0, 1, &scissor);

We bind the graphics pipeline and set the viewports and scissor structures.

            vkCmdDraw(m_cmdBufs[i], 3, 1, 0, 0);

            vkCmdEndRenderPass(m_cmdBufs[i]);

Finally, we record a command to draw. The arguments are the command buffer to record to, number of vertices,
number of instances (for re-running the same drawing ops on different shader parameters), index of the first vertex to
draw and index of the first instance to draw. We can now end the command buffer.

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
