---
title: Урок 51 - Очистка экрана в Vulkan
date: 2016-12-06 16:24:30 +0300
---

Добро пожаловать снова. Я надеюсь что у вас получилось пройти [предыдущий урок](tutorial50.html) и вы
готовы продолжить. В этом уроке мы добавим очень простую операцию, с которой обычно начинают
рендер кадра - очистку экрана. В OpenGL для этого достаточно вызвать функцию *glClear()*, но, как вы могли
уже предположить, в Vulkan это совсем другая история. В этом уроке мы познакомимся с тремя новыми
понятиями Vulkan: цепочки переключений (swap chain), изображения и буферы команд.

Давайте рассмотрим очень простой цикл рендера в OpenGL, который только очищает экран:

    void RenderLoop()
    {
        glClear(GL_COLOR_BUFFER_BIT);
        glutSwapBuffers();   // Или как в GLFW: glfwSwapBuffers(pWindow);
    }

Здесь мы видим комманду GL для очистки буфера цвета, следом за которой идет вызов GLUT или GLFW,
который переключает первый буфер (который отображается на экран) на второй (с которым работает
команда *glClear*). Эти две невинные на первый взляд функции прячут за собой тонну действий
драйвера OpenGL. А Vulkan предоставляет нам стандартный интерфейс для низкоуровневых операций,
которые использует и драйвер OpenGL. Нам же требуется реализовать функционал этих функций
самостоятельно.

Сейчас давайте подумаем что же на самом деле делает драйвер при проходе по циклу рендера. В большинстве
графических драйверов существует такое понятие как буфер команд. Он представляет собой буфер памяти, в
который драйвер записывает инструкции GPU. Драйвер переводит команды GL в инструкции GPU. В GPU, обычно,
существует очередь из всех буферов команд, которые сейчас обрабатываются. GPU выбирает буферы по одному
и выполняет их содержимое. Буфер команд содержит инструкции, указатели на ресурсы, изменения состояний
и всё остальное необходимое для корректного запуска команд OpenGL. Каждый буфер команд может содержать
несколько команд OpenGL (обычно так и происходит из соображений эффективности). За упаковку команд
OpenGL в буферы команд отвечает драйвер. GPU сообщает драйверу когда буфер команд уже заполнен, так что
драйвер может приостановить приложение чтобы оно не обгоняло GPU слишком сильно (например, GPU
рендерит кадр N, а приложение уже на кадре N+10).

Такой подход вполне себе работает, так почему же мы должны его менять? Дело в том, что перекладывание
ответственности за обработку буферов команд на драйвер не даёт нам возможности произвести некоторые
оптимизации, которые можем сделать только мы. Например, вспомним класс Mesh, который мы разрабатывали
в предыдущих уроках когда мы изучали библиотеку Assimp. Рендер меша заключался в том, что мы отправляли
одну и ту же группу команд отрисовки, хотя изменялись лишь матрицы преобразований. Для каждой команды
отрисовки драйвер должен произвести существенное количество работы, и так каждый кадр. А что если бы
мы могли создать заранее буфер команд для этого класса и просто отправлять его каждый кадр (обновляя
при этом матрицы)? В этом и заключается главная идея Vulkan. С точки зрения драйвера OpenGL кадр - это
просто набор команд GL, и драйвер не имеет малейшего понятия что делает приложение. Он даже не подозревает
что эти команды повторятся на следующем кадре. Только разработчик приложения знает что происходит и
может создавать такие буферы команд, которые подойдут приложению лучшим образом.

Другая область в которой OpenGL никогда не блистал, это многопоточность. Отправка команд отрисовки в других
потоках хоть и возможна, но сложна. Проблема в том, что OpenGL создавался без учёта многопоточности. Поэтому,
в большинстве случаев графическое приложение имеет только один поток рендера и использует многопоточность для
всего остального. Vulkan реализует многопоточность позволяя конкурентно создавать буферы команд и добавляет
очереди и семафоры для обработки конкурентности на уровне GPU.

Вернёмся к нашему циклу рендера. На данный момент мы собираемся создать буфер команд и добавить в него
инструкции для очистки. А что насчёт смены буферов? Мы использовали GLUT/GLFW, поэтому никогда не
задумывались об этом. Но GLUT/GLFW не являются частью OpenGL, это всего лишь библиотеки построенные поверх
оконного API, такого как GLX (Linux), WGL (Windows), EGL (Android) и CGL (Mac). Они упрощают процесс написания
ОС-независимых программ OpenGL. Если же использовать API OpenGL напрямую, то вам потребуется создать
контекст и оконную поверхность, что, в общем-то, соответствует экземпляру и поверхности из предыдущего урока.
API предоставляет такие функции, как *glXSwapBuffers()* и *eglSwapBuffers()* для смены буферов, которые
находятся в поверхности. Они не дают большого контроля над буферами.

Vulkan идёт дальше и вводит понятия цепочек переключений, изображений и движка представления. Спецификация
Vulkan описывает цепочки переключений как абстракцию над массивом представляемых изображений, связанных с
поверхностью. Изображения представляют собой то, что будет отображаться на экране, и только одно может быть
выведено на экран одновременно. Пока одно изображение показывается, приложение вольно подготовить и добавить
в очередь остальные изображения. Общее число изображений также подконтрольно приложению.

Движок представления являет собой экран на платформе. Он отвечает за выборку изображений из очереди, вывод их
на экран и уведомление приложения когда изображение можно использовать заново.

Теперь, когда мы разобрались с новыми концептами, давайте разберёмся, что мы должны добавить в предыдущий
урок чтобы заставить его очищать экран. Вот что нам потребуется сделать один раз в процессе инициализации:

1. Получить очередь для буфера команд из логического устройства. Вспомним, что информация, которую поставляет
устройство, включает массив структур *VkDeviceQueueCreateInfo* с количеством очередей каждого семейства.
Для простоты, мы используем только одну очередь из графического семейства. Такая очередь уже была создана
в предыдущем уроке. Мы просто получаем её адрес.

2. Создать цепочку переключений и получить ссылки на её изображения.

3. Создать буфер команд и добавить в него инструкцию для очистки.

А вот что нам потребуется делать в цикле рендера:

1. Получить следующее изображение из цепочки.
2. Отправить буфер команд.
3. Отправить запрос на вывод изображения.

Что же, давайте перейдём к коду.

## [Прямиком к коду!](https://github.com/triplepointfive/ogldev/tree/master/tutorial51)

All the logic that needs to be developed for this tutorial will go into the following class:

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

        std::string m_appName;
        VulkanWindowControl* m_pWindowControl;
        OgldevVulkanCore m_core;
        std::vector&lt;VkImage&gt; m_images;
        VkSwapchainKHR m_swapChainKHR;
        VkQueue m_queue;
        std::vector&lt;VkCommandBuffer&gt; m_cmdBufs;
        VkCommandPool m_cmdBufPool;
    };

What we have here are a couple of public functions (Init() and Run()) that will be called from main() later on and
several private member functions that are based on the steps that were described in the previous section. In addition,
there are a few private member variables. The VulkanWindowControl and OgldevVulkanCore which were part of the main()
function in the previous tutorial were moved here. We also have a vector of images, swap chain object, command queue,
vector of command buffers and a command buffer pool. Now let's look at the Init() function:

    void OgldevVulkanApp::Init()
    {
    #ifdef WIN32
        m_pWindowControl = new Win32Control(m_appName.c_str());
    #else
        m_pWindowControl = new XCBControl();
    #endif
        m_pWindowControl-&gt;Init(WINDOW_WIDTH, WINDOW_HEIGHT);

        m_core.Init(m_pWindowControl);

        <b>vkGetDeviceQueue(m_core.GetDevice(), m_core.GetQueueFamily(), 0, &amp;m_queue);

        CreateSwapChain();
        CreateCommandBuffer();
        RecordCommandBuffers();</b>
    }

This function starts in a similar fashion to the previous tutorial by creating and initializing the window control
and Vulkan core objects. After that we call the private members to create the swap chain and command buffer and
to record the clear instruction into the command buffer. Note the call to vkGetDeviceQueue(). This Vulkan function
fetches the handle of a VkQueue object from the device. The first three parameters are the device, the index of the
queue family and the index of the queue in that queue family (zero in our case because there is only one queue).
The driver returns the result in the last parameter. The two getter functions here were added in this tutorial to the
Vulkan core object.

Let's review the creation of the swap chain step by step:

    void OgldevVulkanApp::CreateSwapChain()
    {
        const VkSurfaceCapabilitiesKHR&amp; SurfaceCaps = m_core.GetSurfaceCaps();

        assert(SurfaceCaps.currentExtent.width != -1);

The first thing we need to do is to fetch the surface capabilities from the Vulkan core object. Remember that in the previous
tutorial we populated a physical device database in the Vulkan core object with info about all the physical
devices in the system. Some of that info was not generic but specific to the combination of the physical
device and the surface that was created earlier. An example is the VkSurfaceCapabilitiesKHR vector which contains a
VkSurfaceCapabilitiesKHR structure for each physical device. The function GetSurfaceCaps() indexes into that vector
using the physical device index (which was selected in the previous tutorial). The VkSurfaceCapabilitiesKHR structure
contains a lot of info on the surface. The currentExtent member describes the current size of the
surface. Its type is a VkExtent2D which contains a width and height. Theoretically, the current extent should contain
the dimensions that we have set when creating the surface and I have found that to be true on both Linux and Windows.
In several examples (including the one in the Khronos SDK) I saw some logic which checks whether the width of the
current extent is -1 and if so overwrites that with desired dimensions. I found that logic to be redundant so I just
placed the assert you see above.

        uint NumImages = 2;

        assert(NumImages &gt;= SurfaceCaps.minImageCount);
        assert(NumImages &lt;= SurfaceCaps.maxImageCount);

Next we set the number of images that we will create in the swap chain to 2. This mimics the behavior
of double buffering in OpenGL. I added assertions to make sure that this number is within the valid range
of the platform. I assume that you won't hit these assertions but if you do you can try with one image only.

        VkSwapchainCreateInfoKHR SwapChainCreateInfo = {};

        SwapChainCreateInfo.sType            = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        SwapChainCreateInfo.surface          = m_core.GetSurface();
        SwapChainCreateInfo.minImageCount    = NumImages;

The function that creates the swap chain takes most of its parameters from the VkSwapchainCreateInfoKHR structure.
The first three parameters are obvious - the structure type, the surface handle and the number of images. Once created
the swap chain is permanently attached to the same surface.

        SwapChainCreateInfo.imageFormat      = m_core.GetSurfaceFormat().format;
        SwapChainCreateInfo.imageColorSpace  = m_core.GetSurfaceFormat().colorSpace;

Next comes the image format and color space. The image format was discussed in the previous tutorial. It describes
the layout of data in image memory. It contains stuff such as channels (red, green and/or blue) and format (float,
normalized int, etc). The color space describes the way the values are matched to colors. For example, this
can be linear or sRGB. We will take both from the physical device database.

        SwapChainCreateInfo.imageExtent      = SurfaceCaps.currentExtent;

We can create the swap chain with a different size than the surface. For now, just grab the current extent from the surface
capabilities structure.

        SwapChainCreateInfo.imageUsage       = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

We need to tell the driver how we are going to use this swap chain. We do that by specifying a combination
of bit masks and there are 8 usage bits in total. For example, the swap chain can be used as a source
or destination of a transfer (buffer copy) operation, as a depth stencil attachment, etc. We just want a standard
color buffer so we use the bit above.

        SwapChainCreateInfo.preTransform     = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;

The pre transform field was designed for hand held devices that can change their orientation (cellular phones
and tablets). It specifies how the orientation must be changed before presentation (90 degrees, 180 degrees, etc).
It is more relevant to Android so we just tell the driver not to do any orientation change.

        SwapChainCreateInfo.imageArrayLayers = 1;

imageArrayLayers is intended for stereoscopic applications where rendering takes place from more than
one location and then combined before presentations. An example is VR where you want to render the scene from each
eye separately. We are not going to do that today so just specify 1.

        SwapChainCreateInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;

Swap chain images can be shared by queues of different families. We will use exclusive access by
the queue family we have selected previously.

        SwapChainCreateInfo.presentMode      = VK_PRESENT_MODE_FIFO_KHR;

In the previous tutorial we briefly touched on the presentation engine which is the part of the platform
involved in actually taking the swap chain image and putting it on the screen. This engine also exists
in OpenGL where it is quite limited in comparison to Vulkan. In OpenGL you can select between single and double buffering.
Double buffering avoids tearing by switching the buffers only on VSync and you have some control on the number
of VSync in a second. That's it. Vulkan, however, provides you with no less than four different modes of operation
that allow a higher level of flexibility and performance. We will be conservative here and use the FIFO mode which
is the most similar to OpenGL double buffering.

        SwapChainCreateInfo.clipped          = true;

The clipped field indicates whether the driver can discard parts of the image that are outside of the visible
surface. There are some obscure cases where this is interesting but not in our case.

        SwapChainCreateInfo.compositeAlpha   = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

compositeAlpha controls the manner in which the image is combined with other surfaces. This is only relevant on
some of the operating systems so we don't use it.

        VkResult res = vkCreateSwapchainKHR(m_core.GetDevice(), &amp;SwapChainCreateInfo, NULL, &amp;m_swapChainKHR);
        CHECK_VULKAN_ERROR("vkCreateSwapchainKHR error %d\n", res);

Finally, we can create the swap chain and get its handle.

        uint NumSwapChainImages = 0;
        res = vkGetSwapchainImagesKHR(m_core.GetDevice(), m_swapChainKHR, &amp;NumSwapChainImages, NULL);
        CHECK_VULKAN_ERROR("vkGetSwapchainImagesKHR error %d\n", res);

When we created the swap chain we specified the minimum number of images it should contain. In the above
call we fetch the actual number of images that were created.

        m_images.resize(NumSwapChainImages);
        m_cmdBufs.resize(NumSwapChainImages);

        res = vkGetSwapchainImagesKHR(m_core.GetDevice(), m_swapChainKHR, &amp;NumSwapChainImages, &amp;(m_images[0]));
        CHECK_VULKAN_ERROR("vkGetSwapchainImagesKHR error %d\n", res);
    }

We have to get the handles of all the swap chain images so we resize the image handle vector accordingly.
We also resize the command buffer vector because we will record a dedicated command buffer for each image in the swap chain.

The following function creates the command buffers:

    void OgldevVulkanApp::CreateCommandBuffer()
    {
        VkCommandPoolCreateInfo cmdPoolCreateInfo = {};
        cmdPoolCreateInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        cmdPoolCreateInfo.queueFamilyIndex = m_core.GetQueueFamily();

        VkResult res = vkCreateCommandPool(m_core.GetDevice(), &amp;cmdPoolCreateInfo, NULL, &amp;m_cmdBufPool);
        CHECK_VULKAN_ERROR("vkCreateCommandPool error %d\n", res);

Command buffer are not created directly. Instead, they must be allocated from pools. As expected, the motivation is
performance. By making command buffers part of a pool, better memory management and reuse can be implemented.
It is imported to note that the pools are not thread safe. This means that any action on the pool or its command
buffers must be explicitly synchronized by the application. So if you want multiple threads to create command
buffers in parallel you can either do this synchronization or simply create a different pool for each thread.

The function vkCreateCommandPool() creates the pool. It takes a VkCommandPoolCreateInfo structure parameter
whose most important member is the queue family index. All commands allocated from this pool must be submitted
to queues from this queue family.

        VkCommandBufferAllocateInfo cmdBufAllocInfo = {};
        cmdBufAllocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        cmdBufAllocInfo.commandPool = m_cmdBufPool;
        cmdBufAllocInfo.commandBufferCount = m_images.size();
        cmdBufAllocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;

        res = vkAllocateCommandBuffers(m_core.GetDevice(), &amp;cmdBufAllocInfo, &amp;m_cmdBufs[0]);
        CHECK_VULKAN_ERROR("vkAllocateCommandBuffers error %d\n", res);
    }

We are now ready to create the command buffers. In the VkCommandBufferAllocateInfo structure we specify the pool
we have just created and the number of command buffers (we need a dedicated command buffer per image in the swap chain).
We also specify whether this is a primary or secondary command buffer. Primary command buffers are the common
vehicle for submitting commands to the GPU but they cannot reference each other. This means that you can
have two very similar command buffers but you still need to record everything into each one. You cannot share
the common stuff between them. This is where secondary command buffers come in. They cannot be directly submitted
to the queues but they can be referenced by primary command buffers which solves the problem of sharing. At this
point we only need primary command buffers.

Now let's record the clear instruction into our new command buffers.

    void OgldevVulkanApp::RecordCommandBuffers()
    {
        VkCommandBufferBeginInfo beginInfo = {};
        beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        beginInfo.flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT;

Recording of command buffers must be done inside a region of the code explictly marked by a vkBeginCommandBuffer() and
vkEndCommandBuffer(). In the VkCommandBufferBeginInfo structure we have a field named 'flags' where we tell the driver
that the command buffers will be resubmitted to the queue over and over again. There are other usage models
but for now we don't need them.

        VkClearColorValue clearColor = { 164.0f/256.0f, 30.0f/256.0f, 34.0f/256.0f, 0.0f };
        VkClearValue clearValue = {};
        clearValue.color = clearColor;

We have to specify our clear color using the two structures above. The first one is a union of four float/int/uint
which allows different ways to do that. The second structure is a union of a VkClearColorValue structure and a
VkClearDepthStencilValue structure. This scheme is used in parts of the API that can take either of the two structures.
We go with the color case. Since I'm very creative today I used the RGB values from the color of the Vulkan logo ;-) <br> Note
that each color channel goes from 0 (darkest) to 1 (brightest) and that this endless spectrum of real numbers is divided to 256
discrete segments which is why I divide by 256.

        VkImageSubresourceRange imageRange = {};
        imageRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        imageRange.levelCount = 1;
        imageRange.layerCount = 1;

We need to specify the range of images that we want to clear. In future tutorials we will study more complex schemes where
there will be multiple mipmap levels, layers, etc. For now we just want the basics so we specify one mip map level and one layer.
The aspectMask field tells the driver whether to clear the color, depth or stenctil (or a combination of them). We are only interested
in the color aspect of the images.


        for (uint i = 0 ; i &lt; m_cmdBufs.size() ; i++) {
            VkResult res = vkBeginCommandBuffer(m_cmdBufs[i], &amp;beginInfo);
            CHECK_VULKAN_ERROR("vkBeginCommandBuffer error %d\n", res);

            vkCmdClearColorImage(m_cmdBufs[i], m_images[i], VK_IMAGE_LAYOUT_GENERAL, &amp;clearColor, 1, &amp;imageRange);

            res = vkEndCommandBuffer(m_cmdBufs[i]);
            CHECK_VULKAN_ERROR("vkEndCommandBuffer error %d\n", res);
        }
    }

We are now ready to record the command buffers. As mentioned earlier, the commands that do the actual recording
must be inside a block marked by calls that begin and end a command buffer. For that we specify the command buffer
to record to and the beginInfo structure which we already prepared. Since we have an array of command buffers (one buffer
per swap chain image) the entire thing is enclosed inside a for loop. vkCmdClearColorImage() records the clear instruction
into the command buffer. As parameters it takes the command buffer to record, the target image, the layout of the image in memory,
the clear color, the number of VkImageSubresourceRange structures to use and a pointer to an array of these structures (only one
in our case).

We prepared everything we need and we can now code our main render function. In standard OpenGL this usually means specifying a
list of GL commands to draw stuff followed by a swap buffers call (be it GLUT, GLFW or any other windowing API). For the driver
it means a tedious repetition of command buffer recording and submission where changes from one frame to the next are relatively small
(changes in shader matrices, etc). But in Vulkan all our command buffers are already recorded! We just need to queue them to the GPU. Since
we have to be more verbose in Vulkan we also need to manage how we acquire and image for rendering and how to tell the presentation
image to display it.

    void OgldevVulkanApp::RenderScene()
    {
        uint ImageIndex = 0;

        VkResult res = vkAcquireNextImageKHR(m_core.GetDevice(), m_swapChainKHR, UINT64_MAX, NULL, NULL, &amp;ImageIndex);
        CHECK_VULKAN_ERROR("vkAcquireNextImageKHR error %d\n", res);

The first thing we need to do is to acquire an image from the presentation engine which is available for rendering.
We can acquire more than one image (e.g. if we plan to render two or more frames ahead) in an advanced scenario but
for now one image will be enough. The API call above takes the device and swap chain as the first two parameters, respectively.
The third parameter is the amount of time we're prepared to wait until that function returns. Often, the presentation engine
cannot provide an image immediately because it needs to wait for an image to be released or some internal OS or GPU event (e.g. the
VSync signal of the display). If we specify zero we make this a non blocking call which means that if an image is available we
get it immediately and if not the function returns with an error. Any value above zero and below the maximum value of an unsigned 64bit
integer will cause a timeout of that number of nanoseconds. The value of UINT64_MAX will cause the function to return only when an image
becomes available (or some internal error occured). This seems like the safest course of action for us here. The next two parameters
are pointers to a semaphore and a fence, respectively. Vulkan was designed with a lot of asynchronous operation in mind. This means
that you can define inter-dependencies between queues on the GPU, between the CPU and GPU, etc. This allows you to submit
work to the image even if it is not really ready to be rendered to (which is a bit counter intuitive to what vkAcquireNextImageKHR is
supposed to do but can still happen). These semaphore and fence are synchornization primitives that must be waited upon before
the actual rendering to the image can begin. A semaphore syncs between stuff on the GPU and the fence between the host CPU
and the GPU. As you can see, I've specified NULL in both cases which might be unsafe and theoretically is not supposed
to work yet it does. This may be because of the simplicity of our application. It allowed me to postpone all the synchronization
business to a later date. Please let me know if you encounter problems because of this. The last parameter to the function is the index
of the image that became available.

        VkSubmitInfo submitInfo = {};
        submitInfo.sType                = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount   = 1;
        submitInfo.pCommandBuffers      = &amp;m_cmdBufs[ImageIndex];

        res = vkQueueSubmit(m_queue, 1, &amp;submitInfo, NULL);
        CHECK_VULKAN_ERROR("vkQueueSubmit error %d\n", res);

Now that we have an image, let's submit the work to the queue. The vkQueueSubmit() function takes the handle of a queue, the number
of VkSubmitInfo structures and a pointer to the corresponding array. The last parameter is a fence which we will conviniently ignore for now.
The VkSubmitInfo actually contains 8 members in addition to the standard sType, but we are going to use only 2 (so just imagine how
much complexity is still down there). We specify that we have one command
buffer and we provide its address (the one that corresponds to the acquired image). The Vulkan spec notes that submission of work can have a high overhead and encourages us to pack as many command
buffers as we possibly can into that API to minimize that overhead. In this simple example we don't have an opportunity to do that but
we should keep that in mind as our application becomes more complex in the future.

        VkPresentInfoKHR presentInfo = {};
        presentInfo.sType              = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        presentInfo.swapchainCount     = 1;
        presentInfo.pSwapchains        = &amp;m_swapChainKHR;
        presentInfo.pImageIndices      = &amp;ImageIndex;

        res = vkQueuePresentKHR(m_queue, &amp;presentInfo);
        CHECK_VULKAN_ERROR("vkQueuePresentKHR error %d\n" , res);
    }

Once the previous API call has returned we know that the command buffer is on its way to the GPU queue but we have no idea
when exactly it is going to be executed, and frankly, we don't really care. Command buffers in a queue are guaranteed to be
processed in the order of submission and since we submit a present command after the clear command into the same queue we
know that the image will be cleared before it is presented. So the vkQueuePresent() call is basically a marker that ends
the frame and tells the presentation engine to display it. This function takes two parameters - a queue which has presentation
capabilities (we took care of that when initializing the device and queue) and a pointer to a VkPresentInfoKHR structure.
This structure contains, among other stuff, two arrays of equal sizes. A swap chain array and an image index array. This means that
you can queue a present command to multiple swap chains where each swap chain is connected to a different window. Every swap chain
in the array has a corresponding image index which specifies which image will be presented. The swapchainCount member says how many
swap chains and images we are going present.

    void OgldevVulkanApp::Run()
    {
        while (true) {
            RenderScene();
        }
    }

Our main render function is very simple. We loop endlessly and call the function that we have just reviewed.

    int main(int argc, char** argv)
    {
        OgldevVulkanApp app("Tutorial 51");

        app.Init();

        app.Run();

        return 0;
    }

The main function is also very simple. We declare an OgldevVulkanApp object, initialize and run it.

That's it for today. I hope that your window is clear. Next time we will draw a triangle.
