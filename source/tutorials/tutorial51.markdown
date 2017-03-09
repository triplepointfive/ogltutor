---
title: Урок 51 - Clear Screen in Vulkan
date: 2016-12-06 16:24:30 +0300
---

Добро пожаловать снова. Я надеюсь что у вас получилось пройти [предыдущий урок](tutorial50.html) и вы
готовы продолжить. В этом уроке мы добавим очень простую операцию, с которой обычно начинают
рендер кадра - очистку экрана. В OpenGL для этого достаточно вызвать функцию *glClear()*

Welcome back. I hope that you've been able to complete the <a href="http://ogldev.atspace.co.uk/www/tutorial50/tutorial50.html">previous tutorial</a> successfully and
you are now ready to continue. In this tutorial we will do a very basic operation that usually starts
a new frame - clear the screen. In OpenGL this can be done very easily with just the
command but as you can already assume - it's a totally different ball game with Vulkan. This tutorial will introduce us
to three new and improtant Vulkan entities - swap chain, images and the command buffers.

Let's look at a very simple OpenGL render loop which just clears the screen:

    void RenderLoop()
    {
        glClear(GL_COLOR_BUFFER_BIT);
        glutSwapBuffers();   // Or in GLFW: glfwSwapBuffers(pWindow);
    }

What we have here is a GL command to clear the color buffer followed by a GLUT or GLFW call that
swaps the front buffer which is currently being displayed with the back buffer (which is really the
buffer that glClear targeted). These two seemingly innocent functions hide a ton of back stage activity
by the OpenGL driver. What Vulkan does is to provide us with a standard interface to the low level
operations that used to be the sole domain of the OpenGL driver. Now we have to take control and manage
these back stage activities ourselves.

So now let's think what really happens in the driver when it executes that render loop. In most graphics drivers
there is a concept of a command buffer. The command buffer is a memory buffer that the driver fills with
GPU instructions. The driver translates the GL commands into GPU instructions. It submits the command buffer to the GPU and there is usually some form of a queue of
all the command buffers that are currently in flight. The GPU picks up the command buffers one by one and
executes their contents. The command buffers contain instructions, pointers to resources, state changes and everything else
that the GPU needs in order to execute the the OpenGL commands correctly. Each command buffer
can potentially contain multiple OpenGL commands (and it usually does because it is more efficient). It is up to the driver to decide how to batch the OpenGL commands
into the command buffers. The GPU informs the driver whenever
a command buffer is completed and the driver can stall the application to prevent it from getting too much
ahead of the GPU (e.g. the GPU renders frame N while the application is already at frame N+10).

This model works pretty well. Why do we need to change it? Well, making the driver in charge of command
buffer management prevents us from some important potential performance optimizations that only we can
make. For example, consider
the Mesh class that we developed in previous tutorials when we studied the Assimp library. Rendering a mesh
meant that in each frame we had to submit the same group of draw commands when the only real change was a few
matrices that controlled the transformation. For each draw command the driver had to do considerable amount of work
which is a waste of time in each frame. What if we could create a command buffer for this mesh class ahead of
time and just submit it in each frame (while changing the matrices somehow)? That's the whole idea behind Vulkan. For the OpenGL driver the frame
is just a series of GL commands and the driver doesn't understand what exactly the application is doing.
It doesn't even know that these commands will be repeated in the next frame. Only the app designer understands what's going
on and can create command buffers in a way that will match the structure of the application.

Another area where OpenGL never excelled in is multi threading. Submitting draw commands in different
threads is possible but complex. The problem is that OpenGL was not designed with multi threading in mind. Therefore,
in most cases a graphics app has one rendering thread and uses multi-threading for the rest of the logic. Vulkan
addresses multi threading by allowing you to build command buffers concurrently and introduces the concept of
queues and semaphores to handle concurrency at the GPU level.

Let's get back to that render loop. By now you can imagine that what we are going to do is create a command buffer
and add the clear instruction to it. What about swap buffers? We have been using GLUT/GLFW so we never gave much thought
about it. GLUT/GLFW are not part of OpenGL. They are libraries built on top of windowing APIs such as GLX (Linux), WGL (Windows),
EGL (Android) and CGL (Mac). They make it easy to build OS independent OpenGL programs. If you use the underlying APIs directly
you will have to create an OpenGL context and window surface which are in general corresponding to the instance and surface
we created in the previous tutorial. The underlying APIs provide functions such as glXSwapBuffers() and eglSwapBuffers() in
order to swap the front and back buffers that are hidden under the cover of the surface. They don't provide you much control
beyond that.

Vulkan goes a step further by introducing the concepts of swap chain, images and presentation engine. The Vulkan spec
describes the swap chain as an abstraction of an array of presentable images that are associated with the surface. The images
are what is actually being displayed on the screen and only one can be displayed at a time. When an image is displayed the
application is free to prepare the remaining images and queue them for presentation. The total number of images
can also be controlled by the application.

The presentation engine represents the display on the platform. It is responsible for picking up images from the queue,
presenting them on the screen and notifying the application when an image can be reused.

Now that we understand these concepts let's review what we need add to the previous tutorial in order to make
it clear the screen. Here's the one time initialization steps:

1.  Get the command buffer queue from the logical device. Remember that the device create info included
an array of VkDeviceQueueCreateInfo structures with the number of queues from each family to create.
For simplicity we are using just one queue from graphics family. So this queue was already created in
the previous tutorial. We just need to get its address.

2. Create the swap chain and get the handles to its images.

3. Create a command buffer and add the clear instruction to it.

And here's what we need to do in the render loop:

1. Acquire the next image from the swap chain.
2. Submit the command buffer.
3. Submit a request to present the image.

Now let's review the code to accomplish this.

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
