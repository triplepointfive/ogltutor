---
title: Урок 50 - Введение в Vulkan
date: 2016-12-06 16:24:30 +0300
---

Думаю, вы как минимум слышали об [Vulkan API](https://www.khronos.org/vulkan/) -
новом графическом API от Khronos (некоммерческая организация разрабатывающая
OpenGL). Vulkan был анонсирован в феврале 2016, через 24 года после OpenGL, и
является полностью новым стандартом и уходом от текущей модели. Я не буду глубоко
вдаваться в отличия Vulkan, а только скажу, что он в разы более низкоуровневый
чем OpenGL, и даёт разработчику большой контроль над производительностью. Но с
большой силой приходит и большая ответственность. Разработчик должен взять под
контроль самые разные аспекты, например, буфер команд, синхронизацию и
управление памятью; ранее этим занимался драйвер. Но благодаря знанию структуры
приложения в деталях, разработчик может добиться максимальной производительности
используя Vulkan API нужным ему образом.

На мой взгляд, больше всего в Vulkan людей шокирует то, сколько требуется написать
кода просто для того, что бы вывести на экран первый треугольник. В первых уроках
по OpenGL для этого потребуется буквально пара строк, но здесь, для многих, желающих начать
цикл статей по Vulkan, это становится целым испытанием. Поэтому, как и всегда для
OGLDEV, я начну представлять материал по шагам. Мы выведем первый треугольник за
пару уроков, понемногу продвигаясь в каждом. Кроме того, я постараюсь не
вываливать дюжину вызовов API в одном длинном куске кода, а сразу начну
заворачивать в приложение с простым дизайном, который, я надеюсь, пригодится вам
для будущих приложений. Но в любом случае, это обучающее приложение, и не
стесняйтесь его изменять под себя.

Двигаясь по коду мы будем поочередно изучать ключевые компоненты Vulkan, поэтому
сейчас я просто хочу представить общую диаграмму:

![](/images/50/vulkan.jpg)

Эта диаграмма ни в коем случае не претендует на полноту. Она содержит только
основные компоненты, которые будут использоваться в большинстве приложений. Связи
между компонентами обозначают зависимости в момент создания, либо перечисления.
Например, для создания поверхности требуется экземпляр объекта, а когда вы
перечисляете физические устройства системы, то также потребуется экземпляр. Два
цвета объясняют наш дизайн в общих чертах. Красный объединяет то, что я бы
назвал "ядром", а зелёный те части, которые будут "приложением". Позже мы
разберем для чего это нужно. Код самого приложения, которое вы будете писать,
будет наследоваться от "приложения", и все его части будут вам доступны для
использования. Очень надеюсь, что такой дизайн поможет нам в разработке следующих
частей этого цикла по Vulkan.

### **Подготовка системы**

Первое что нам нужно, это проверить, что система поддерживает Vulkan, и
подготовить всё для разработки. Вы должны проверить, что ваша видеокарта поддерживает
Vulkan, и установить свежие драйвера. Так как Vulkan вышел в свет ещё совсем недавно,
то лучше проверять обновления драйверов как можно чаще, там могут быть исправления
ошибок. Поскольку существует огромное число GPU, я не могу подробно рассказать о
каждом. Обновление / установка драйверов под Windows не должна вызвать затруднений.
Под Linix могут потребоваться некоторые танцы с бубном. Для разработки я использую
Linux Fedora с видеокартой GT710 от NVIDIA на борту. NVIDIA предоставляет один
бинарный файл, который может быть установлен только из командной строки. У других
производителей всё может быть иначе. Под Linux вы можете использовать *lspci* для
скана системы и поиска своего GPU. Попробуйте добавить опции *-v*, *-vv* и *-vvv*
чтобы увидеть больше деталей.

Далее нам потребуется установить Vulkan SDK от компании Khronos, скачать который
можно [по ссылке](https://vulkan.lunarg.com/). SDK, помимо заголовочных файлов и
библиотек, включает в себя большое число примеров, которые вы можете использовать
для лучшего ознакомления с возможностями API. На момент написания урока актуальная
версия SDK 1.0.30.0, и я призываю вас регулярно проверять обновления, так как
SDK сейчас находится в активной разработке. В нескольких следующих разделах версия
будет указываться в командах в явном виде, так что не забывайте изменять её на
ту, которую вы устанавливаете.

### Linux

Khronos предоставляет запускаемый файл предназначенный для Ubuntu. После запуска он
устанавливает всё что требуется, но при запуске под Fedora я столкнулся с некоторыми
сложностями. Я использовал следующие команды:

- bash$ chmod +x vulkansdk-linux-x86_64-1.0.30.0.run
- base$ ./vulkansdk-linux-x86_64-1.0.30.0.run **--target** VulkanSDK-1.0.30.0 **--noexec**
- base$ ln -s ~/VulkanSDK-1.0.30/1.0.30.0 ~/VulkanSDK

Эти команды извлекают содержимое пакета без запуска внутренних скриптов. После распаковки
директория *VulkanSDK-1.0.30.0* будет содержать каталог *1.0.30.0* с файлами пакета.
Предположим, что я запускал эти команды находясь в домашнем каталоге (известном как *\~*),
тогда мы получим символьную ссылку *~/VulkanSDK* на каталог с содержимым пакета (с
каталогами *source*, *samples*, и т.д.). Ссылка упрощает переключение среды разработки на
более свежую версию. По ссылке можно получить библиотеки и заголовочные файлы. Чуть позднее
мы разберемся с тем, как их использовать. А пока что сделайте следующее:

- bash$ cd VulkanSDK/1.0.30.0
- bash$ ./build_examples.sh

Если всё прошло успешно, то примеры были собраны в *examples/build*. Для их запуска вы должны
*cd* в этот каталог. А теперь попробуйте запустить *./cube* и *./vulkaninfo* чтобы убедиться,
что Vulkan запускается на вашей системе, и получить информацию о драйвере.

Надеюсь, что всё прошло успешно, так что мы можем добавить немного символических ссылок, чтобы
удобнее обращаться к файлам, которые нам требуются для разработки. Зайдите под суперпользователем
(с помощью вызова *su* и ввода пароля) и запустите команды:

- bash# ln -s /home/&lt;your username&gt;/VulkanSDK/x86_x64/include/vulkan /usr/include
- base# ln -s /home/&lt;your username&gt;/VulkanSDK/x86_x64/lib/libvulkan.so.1 /usr/lib64
- base# ln -s /usr/lib64/libvulkan.so.1 /usr/lib64/libvulkan.so

С помощью этих трёх команд мы добавили символические ссылки из */usr/include* в каталог
заголовочных файлов Vulkan. Кроме того, мы добавили ссылки на динамические библиотеки,
которые будут использоваться при линковке. Теперь, если мы обновили SDK, то нам требуется только
изменить ссылку *~/VulkanSDK* на местоположение новой версии. Отметим, что вызов команд из-под
рута требуется только один раз. После обновления SDK потребуется изменить ссылку только в
домашнем каталоге. Вы, конечно, можете дать ссылке любое имя, но код, который идет с
моими уроками, предполагает, что она находится в домашнем каталоге.

### Windows

Установка под Windows ощутимо проще чем под Linux. Просто скачайте последнюю версию
[здесь](https://vulkan.lunarg.com/sdk/home#windows), дважды кликните по файлу установщика,
согласитесь со всем, что вам предложат, выберите директорию установки, и, в общем-то, всё.
Я бы предложил установить SDK в *c:\\VulkanSDK* для обеспечения совместимости с моим проектом
Visual Studio. Если вы устанавливаете куда-то ещё, то не забудьте обновить в проекте
директории с заголовочными файлами и библиотеками. Детали вы найдете в следующем разделе.

### **Сборка и запуск**

### Linux

Под Linux я в основном разрабатываю в [Netbeans](http://www.netbeans.org/).
Код, который идет с уроками, содержит проекты сборки Netbeans для C/C++. Если
вы установили SDK как я написал выше, то эти проекты должны работать их коробки
(и, пожалуйста, сообщайте мне о любых проблемах). Если вы используете другую
систему сборки, убедитесь, что вы добавили:

- В команду компиляции: **-I&lt;path to VulkanSDK/1.0.30.0/x86_64/include&gt;**
- В команду линковки: **-L&lt;path to VulkanSDK/1.0.30.0/x86_64/lib&gt; -lxcb -lvulkan'**

Даже если вы не используете Netbeans, вы всё ещё можете скомпилировать урок
командой *make*. Netbeans самостоятельно генерирует Makefile. Этого будет
достаточно, чтобы проверить настройку системы. Для этого скачайте
[исходники](http://ogldev.org/ogldev-source.zip), разархивируйте их, зайдите в
каталог *ogldev/tutorial50*, а затем запустите команду *make*. Если вы всё
сделали правильно, то вы можете запустить *dist/Debug/GNU-Linux-x86/tutorial50*
из *ogldev/tutorial50*.

### Windows

Если вы установили SDK в *c:\\VulkanSDK*, то мои проекты Visual Studio должны
работать прямо из коробки. Если же нет, или вы хотите создать новый проект
Visual Studio, то сделайте так:

Для обновления каталога с заголовочными файлами нажмите на проект в окошке
*solution explorer*, перейдите в *Properties*, а затем в
*Configuration Properties -&gt; C/C++ -&gt; General*. Теперь вы должны добавить
*c:\\VulkanSDK\\&lt;version&gt;\\Include* в *Additional Include Directories*.
Пример приведен ниже:

![](/images/50/include.jpg)

Для обновления каталога с файлами библиотеки нажмите правой кнопкой мыши на проект
в окошке *solution explorer*, перейдите в *Properties* и затем в
*Configuration Properties -&gt; Link -&gt; General*. Теперь вы должны добавить
*c:\\VulkanSDK\\&lt;version&gt;\\Bin32* в поле *Additional Library Directories*.
Пример приведен ниже:

![](/images/50/link.jpg)

Пока вы ещё настраиваете линковщик зайдите в *Input* (сразу же под *General*), а
затем добавьте *vulkan-1.lib* в поле *Additional Dependencies*.

### **Общие комментарии**

Прежде чем мы перейдем к коду, я бы хотел отметить некоторые мои решения о
дизайне приложений с использованием Vulkan.

1. Многие функции в Vulkan (особенно те, которые создают объекты) принимают на
вход параметр - структуру. Такая структура используется как обертка над большей
частью параметров, которые нужны функции. Благодаря этому у функций ощутимо меньше
входящих параметров. Разработчики Vulkan решили, что первым параметром у таких
структур будет свойство *sType*. Оно имеет перечислимый тип, и для каждой структуры
свой код. Это позволяет драйверу определять тип структуры, зная только её адрес.
У каждого кода есть префикс **VK_STRUCTURE_TYPE_**. Например, код структуры
используемой при создании экземпляра **VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO**.

    Каждый раз когда я объявляю переменную с типом одной из этих структур, первое
    что я делаю, это обновляю значение *sType*. Для экономии бумаги в дальнейшем я
    не буду это упоминать.

2. Ещё одно важное замечание об этих структурах - у них очень много свойств,
которые нас пока не волнуют. Что бы код был компактнее (а уроки короче...) я
всегда буду инициализировать структуры нулями (с помощью нотации **struct = {}**)
и в явном виде обозначать только те свойства, которые не могут быть нулями.
Я объясню их в следующих уроках, когда эти свойства будут востребованы.

3. В Vulkan функции либо являются процедурами, либо возвращают код ошибки в объекте
**VkResult**. Код ошибки является перечислением, где **VK_SUCCESS** равно 0,
а все остальные коды ошибок больше 0. По мере возможностей я добавляю проверку на
ошибки. Если возникла ошибка, то я вывожу сообщение в консоль (а в Window в отдельном
окошке) и выхожу. Обработка ошибок в реальном приложении слишком усложняет код, а
моя задача сохранить простоту.

4. Многие функции Vulkan (особенно те, которые создают объекты) принимают на вход
функцию выделения памяти. Такой подход позволяет контролировать процесс выделения
памяти Vulkan. На мой взгляд это тема для уже опытных разработчиков, поэтому мы
не будем заморачиваться с этим и всегда будем передавать NULL. В этом случае
драйвер будет использовать свою функцию по умолчанию.

5. Vulkan не гарантирует экспорт своих функций в библиотеке. Это значит, что на
некоторых платформах вы можете получить *segmentation fault* при вызове функции
Vulkan так как она оказалась равна NULL. В этом случае вы вынуждены использовать
**vkGetInstanceProcAddr()** для получения адреса функции перед её использованием
(вспомним, что в OpenGL для этой проблемы мы использовали GLEW). В моем случае
только vkCreateDebugReportCallbackEXT() была не доступна. Эта функция требуется
только для дополнительной проверочной прослойки. Поэтому, я решил рискнуть и
для всех функций которые я использую в уроке не получать адресов. Если поступят
жалобы, то я обновлю код урока.

6. Каждое серьезное приложение обязано позаботиться об освождении память, иначе
не избежать утечек. В этом уроке я не стал усложнять и не уничтожаю никакие
объекты. В любом случае они удалятся при завершении программы. В будущем я,
возможно, ещё вернусь к этой теме, но пока просто запомните, что почти все
функции вида &lt;**vkCreate*()** имеют в пару **vkDestroy*()**. И будьте
осторожны при удалении объектов пока программа ещё работает. Больше деталей вы
найдете по [ссылке](https://www.khronos.org/registry/vulkan/specs/1.0-wsi_extensions/xhtml/vkspec.html#fundamentals-objectmodel-overview).

### **Структура проекта**

Далее приведен краткий перечень файлов, которые мы собираемся обозревать.

1. **tutorial50/tutorial50.cpp** - здесь определена функция *main()*.

2. **include/ogldev_vulkan.h** - основной заголовочный и единственный файл в
котором загружаются заголовочные файлы Vulkan. Вы можете включить проверочную
прослойку раскоментив **ENABLE_DEBUG_LAYERS**. Этот файл содержит несколько
вспомогательных функций и макросов, а так же определение класса **VulkanWindowControl**.

3. **Common/ogldev_vulkan.cpp** - реализация функций, определённых в *ogldev_vulkan.h*.

4. **include/ogldev_vulkan_core.h** - объявление главного класса **OgldevVulkanCore** в
котором сосредоточена вся суть.

5. **Common/ogldev_vulkan_core.cpp** - реализация класса **OgldevVulkanCore**.

6. **include/ogldev_xcb_control.h** - объявление класса **XCBControl**, который
создает окно в Linux.

7. **Common/ogldev_xcb_control.cpp** - реализация **XCBControl**.

8. **include/ogldev_win32_control.h** - объявление класса **Win32Control**, который
создает окно в Windows.

9. **Common/ogldev_win32_control.cpp** - реализация **Win32Control**.

Как в Netbeans, так и в Visual Studio файлы разделены между проектами *tutorial50* и *Common*.

## [Прямиком к коду!](https://github.com/triplepointfive/ogldev/tree/master/tutorial50)

Я надеюсь, что вы справились с первой частью и теперь полностью готовы
погрузиться в Vulkan. Как я уже говорил, мы собираемся разработать наше первое
демо приложение в несколько этапов. Первым шагом будет настроить самые основные
объекты Vulkan: экземпляр, поверхность, физическое и логическое устройства.
Я буду объяснять следуя моему дизайну приложения, но вы вольны пропустить эту
часть и изучать только обращения к Vulkan.

В самом начале мы включаем заголовки Vulkan. В моем проекте все файлы Vulkan
включаются только в файле *ogldev_vulkan.h*. Поэтому во всём остальном проекте
включается только этот файл. Вот соответствующие куски кода:

    #ifdef _WIN32
    #define VK_USE_PLATFORM_WIN32_KHR
    #include "vulkan/vulkan.h"
    #include "vulkan/vk_sdk_platform.h"
    #else
    #define VK_USE_PLATFORM_XCB_KHR
    #include <vulkan/vulkan.h>
    #include <vulkan/vk_sdk_platform.h>
    #endif

Обратите внимание на то, что мы добавили различные макросы для Windows и Linux.
Эти макросы включают дополнения для поддержки оконной системы для каждой ОС.
Причина, по которой включение заголовков отличается кавычками, в том, что в
Linux эти файлы устанавливаются в системный каталог (**/usr/include/vulkan**),
а в Windows в стандартный каталог.

Давайте начнем обзор с класса **OgldevVulkanCore**, который отвечает за создание
и работу с основными объектами.

    class OgldevVulkanCore
    {
    public:
        OgldevVulkanCore(const char* pAppName);
        ~OgldevVulkanCore();

        bool Init(VulkanWindowControl* pWindowControl);

        const VkPhysicalDevice& GetPhysDevice() const;

        const VkSurfaceFormatKHR& GetSurfaceFormat() const;

        const VkSurfaceCapabilitiesKHR GetSurfaceCaps() const;

        const VkSurfaceKHR& GetSurface() const { return m_surface; }

        int GetQueueFamily() const { return m_gfxQueueFamily; }

        VkInstance& GetInstance() { return m_inst; }

        VkDevice& GetDevice() { return m_device; }

    private:
        void CreateInstance();
        void CreateSurface();
        void SelectPhysicalDevice();
        void CreateLogicalDevice();

        // Объекты Vulkan
        VkInstance m_inst;
        VkDevice m_device;
        VkSurfaceKHR m_surface;
        VulkanPhysicalDevices m_physDevices;

        // Внутрение детали
        std::string m_appName;
        int m_gfxDevIndex;
        int m_gfxQueueFamily;
    };

Помимо вектора объектов Vulkan *m_physDevices* (инициирован будет далее), класс
включает в себя три свойства Vulkan (*m_inst*, *surface* и *m_device*). Кроме
того, мы храним название приложения, индекс используемого физического устройства и
индекс набора очередей. Класс также содержит несколько методов чтения и функцию Init(), которая всё настраивает.
Давайте разберёмся, что же она делает.

    void OgldevVulkanCore::Init(VulkanWindowControl* pWindowControl)
    {
        std::vector<VkExtensionProperties> ExtProps;
        VulkanEnumExtProps(ExtProps);

        CreateInstance();

        #ifdef WIN32
        assert(0);
        #else
        m_surface = pWindowControl->CreateSurface(m_inst);
        assert(m_surface);
        #endif
        printf("Surface created\n");

        VulkanGetPhysicalDevices(m_inst, m_surface, m_physDevices);
        SelectPhysicalDevice();
        CreateLogicalDevice();
    }

Эта функция принимает на вход объект *VulkanWindowControl*. Мы потом разберёмся с этим
объектом. Пока что достаточно сказать, что это ОС зависимый класс, задача которого - это
создание оконной поверхности, на которую будет происходить рендер. Совсем как и в OpenGL,
ядро Vulkan не содержит работы с окнами. Эта задача отдана расширениям, и у нас есть
полный набор для всех основных ОС. Участники Khronos могут публиковать свои собственные
расширения в общем [регистре](https://www.khronos.org/registry/vulkan/). Разработчики
драйверов сами решают какие из разрешений они хотят реализовывать. А уже пользователи
Vulkan могут во время работы приложения смотреть в список доступных разрешений и
решать что с ними делать.

Мы начнем с перечисления всех расширений. Происходит это в следующей функции -
декораторе:

    void VulkanEnumExtProps(std::vector<vkextensionproperties>& ExtProps)
    {
        uint NumExt = 0;
        VkResult res = vkEnumerateInstanceExtensionProperties(NULL, &NumExt, NULL);
        CHECK_VULKAN_ERROR("vkEnumerateInstanceExtensionProperties error %d\n", res);

        printf("Found %d extensions\n", NumExt);

        ExtProps.resize(NumExt);

        res = vkEnumerateInstanceExtensionProperties(NULL, &NumExt, &ExtProps[0]);
        CHECK_VULKAN_ERROR("vkEnumerateInstanceExtensionProperties error %d\n", res);

        for (uint i = 0 ; i < NumExt ; i++) {
            printf("Instance extension %d - %s\n", i, ExtProps[i].extensionName);
        }
    }

Функция выше обрамляет вызов **vkEnumerateInstanceExtensionProperties()** к
Vulkan API, который возвращает доступные в системе расширения. То, как мы
используем это функцию, очень распространённая методика в Vulkan. Первый вызов возвращает
количество расширений. Это число мы используем для задания размера вектора
расширений. Второй вызов уже возвращает сами расширения. Первый параметр
позволяет выбрать прослойку. Vulkan устроен таким образом, что производители
видеокарт могут добавлять логические прослойки для валидации, дополнительной
отладочной печати и другие. Во время работы приложения мы вольны выбирать, какой
из слоев включить. Например, во время разработки включить слой с проверками
данных, а в готовой версии приложения уже отключать. Так как нам нужны
все расширения, то мы передаем NULL в качестве слоя.

После получения списка расширений мы печатаем их. Если вы хотите произвести
какие-то действия со списком расширений, то эту логику можно добавить сюда.
Печать списка расширений позволит убедиться в том, что требуемые далее
расширения включены в этот список. Следующий этап инициализации заключается
в создании экземпляра Vulkan:

    void OgldevVulkanCore::CreateInstance()
    {
        VkApplicationInfo appInfo = {};
        appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName = m_appName.c_str();
        appInfo.engineVersion = 1;
        appInfo.apiVersion = VK_API_VERSION_1_0;

        const char* pInstExt[] = {
    #ifdef ENABLE_DEBUG_LAYERS
            VK_EXT_DEBUG_REPORT_EXTENSION_NAME,
    #endif
            VK_KHR_SURFACE_EXTENSION_NAME,
    #ifdef _WIN32
            VK_KHR_WIN32_SURFACE_EXTENSION_NAME,
    #else
            VK_KHR_XCB_SURFACE_EXTENSION_NAME
    #endif
        };

    #ifdef ENABLE_DEBUG_LAYERS
        const char* pInstLayers[] = {
            "VK_LAYER_LUNARG_standard_validation"
        };
    #endif

        VkInstanceCreateInfo instInfo = {};
        instInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        instInfo.pApplicationInfo = &appInfo;
    #ifdef ENABLE_DEBUG_LAYERS
        instInfo.enabledLayerCount = ARRAY_SIZE_IN_ELEMENTS(pInstLayers);
        instInfo.ppEnabledLayerNames = pInstLayers;
    #endif
        instInfo.enabledExtensionCount = ARRAY_SIZE_IN_ELEMENTS(pInstExt);
        instInfo.ppEnabledExtensionNames = pInstExt;

        VkResult res = vkCreateInstance(&instInfo, NULL, &m_inst);
        CHECK_VULKAN_ERROR("vkCreateInstance %d\n", res);

    #ifdef ENABLE_DEBUG_LAYERS
        // Получаем адрес функции vkCreateDebugReportCallbackEXT
        my_vkCreateDebugReportCallbackEXT = reinterpret_cast<pfn_vkcreatedebugreportcallbackext>(vkGetInstanceProcAddr(m_inst, "vkCreateDebugReportCallbackEXT"));

        // Регистрируем функцию отладки
        VkDebugReportCallbackCreateInfoEXT callbackCreateInfo;
        callbackCreateInfo.sType       = VK_STRUCTURE_TYPE_DEBUG_REPORT_CREATE_INFO_EXT;
        callbackCreateInfo.pNext       = NULL;
        callbackCreateInfo.flags       = VK_DEBUG_REPORT_ERROR_BIT_EXT |
                                         VK_DEBUG_REPORT_WARNING_BIT_EXT |
                                         VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT;
        callbackCreateInfo.pfnCallback = &MyDebugReportCallback;
        callbackCreateInfo.pUserData   = NULL;

        VkDebugReportCallbackEXT callback;
        res = my_vkCreateDebugReportCallbackEXT(m_inst, &callbackCreateInfo, NULL, &callback);
        CheckVulkanError("my_vkCreateDebugReportCallbackEXT error %d\n", res);
    #endif
    }


Для инициализации библиотеки Vulkan мы должны создать экземпляр - объект
**VkInstance**. Этот объект хранит состояние приложения. Функция, которая
создает его, называется **vkCreateInstance()**, и ей требуется большая часть
свойств структуры **VkInstanceCreateInfo**. Интересующие нас параметры, это
список расширений и (дополнительно) список слоев, которые мы хотим включить.
Из расширений это расширение общей поверхности и расширение для ОС зависимой
поверхности. Слои и расширения определяются через их название - строку, а для
некоторых из них Khronos SDK предлагает макрос. **VkInstanceCreateInfo** также
принимает указатель на структуру **VkApplicationInfo**. Эта структура содержит
свойства приложения, а разработчик может задать название и некоторую
внутреннюю версию движка. Свойство VkApplicationInfo, на которое стоит обратить
внимание, это *apiVersion*. Это задает минимальную версию Vulkan, которая
требуется приложению. Если в системе установлена версия меньше, то этот
вызов бросит ошибку. Мы запрашиваем версию 1.0, так что всё должно быть в порядке.


После того как в наши руки попадёт экземпляр мы сможем зарегистрировать в
проверяющим слое функцию, которая будет печатать предупреждения и сообщения об
ошибках. Для этого получаем указатель на функцию **vkCreateDebugReportCallbackEXT**,
затем мы заполняем структуру **VkDebugReportCallbackCreateInfoEXT** флагами о
тех аспектах, о которых драйвер должен нас уведомлять, и указателем на нашу
функцию отладки. В действительности регистрация происходит при вызове функции,
указатель на которую мы получили ранее. Мы получаем указатель на функцию
**vkCreateDebugReportCallbackEXT** и наша функция обратного вызова для отладки
имеет следующий вид:

    PFN_vkCreateDebugReportCallbackEXT my_vkCreateDebugReportCallbackEXT = NULL;

    VKAPI_ATTR VkBool32 VKAPI_CALL MyDebugReportCallback(
        VkDebugReportFlagsEXT       flags,
        VkDebugReportObjectTypeEXT  objectType,
        uint64_t                    object,
        size_t                      location,
        int32_t                     messageCode,
        const char*                 pLayerPrefix,
        const char*                 pMessage,
        void*                       pUserData)
    {
        printf("%s\n", pMessage);
        return VK_FALSE;    // Т.к. мы не хотим чтобы вызывающая функция упала.
    }

Далее мы создадим оконную поверхность. Для этого мы воспользуемся объектом
**VulkanWindowControl**, указатель на который получает функция *Init()*. С этим
классом мы познакомимся позднее, поэтому не будем на нём сейчас останавливаться
(обратите внимание на то, что для создания поверхности используется экземпляр;
поэтому мы и создаём объекты в этом порядке).

После создания экземпляра и поверхности мы готовы к получению информации о
физических устройствах системы. Под физическим устройством мы понимаем либо
дискретную, либо интегрированную видеокарту. Например, ваш компьютер может
иметь две видеокарты NVIDIA с технологией SLI и графический GPU Intel HD,
встроенный в CPU. В этом случае у вас три физических устройства. Функция ниже
получает все физические устройства и некоторые их характеристики в виде
структуры **VulkanPhysicalDevices**. Структура, по сути, представляет собой
базу данных физических устройств и их свойств. Она состоит из нескольких
векторов (иногда векторов векторов) объектов Vulkan. Для получения доступа к
конкретному устройству вы должны получить индекс устройства и с ним обращаться
к вектору. То есть, для получения информации о физическом устройстве с индексом
2 обращайтесь к *m_device[2]* и *m_devProps[2]*, и так далее. Причина, по
которой я выбрал такую структуру (а не один объект на устройство), в том, что
это совпадает с форматом API Vulkan. Вы предоставляете массив XYZ и получаете
все XYZ объекты для всех физических устройств. Вот определение этой схожей
с базой данных структуры:

    struct VulkanPhysicalDevices {
        std::vector<VkPhysicalDevice> m_devices;
        std::vector<VkPhysicalDeviceProperties> m_devProps;
        std::vector< std::vector<VkQueueFamilyProperties> > m_qFamilyProps;
        std::vector< std::vector<VkBool32> > m_qSupportsPresent;
        std::vector< std::vector<VkSurfaceFormatKHR> > m_surfaceFormats;
        std::vector<VkSurfaceCapabilitiesKHR> m_surfaceCaps;
    };

Теперь давайте рассмотрим функцию заполнения базы данных. Первых два параметра
представляют собой экземпляр и поверхность. Третий параметр это то, куда будут
записаны данные. Мы будем изучать функцию по частям.

    void VulkanGetPhysicalDevices(const VkInstance& inst, const VkSurfaceKHR& Surface, VulkanPhysicalDevices& PhysDevices)
    {
        uint NumDevices = 0;

        VkResult res = vkEnumeratePhysicalDevices(inst, &NumDevices, NULL);
        CHECK_VULKAN_ERROR("vkEnumeratePhysicalDevices error %d\n", res);
        printf("Num physical devices %d\n", NumDevices);

Вначале мы должны получить число физических устройств. И снова мы видим систему
из двух вызовов - первый для получения количества элементов, а второй для
получения уже самих значений.

        PhysDevices.m_devices.resize(NumDevices);
        PhysDevices.m_devProps.resize(NumDevices);
        PhysDevices.m_qFamilyProps.resize(NumDevices);
        PhysDevices.m_qSupportsPresent.resize(NumDevices);
        PhysDevices.m_surfaceFormats.resize(NumDevices);
        PhysDevices.m_surfaceCaps.resize(NumDevices);

Мы можем изменить размер базы данных таким образом, чтобы вмещать все элементы.

        res = vkEnumeratePhysicalDevices(inst, &NumDevices, &PhysDevices.m_devices[0]);
        CHECK_VULKAN_ERROR("vkEnumeratePhysicalDevices error %d\n", res);

И ещё раз этот вызов, но уже с адресом вектора *VkPhysicalDevice*. Очень удобно
использовать векторы из стандартной библиотеки, так как они функционируют как
обычные массивы - адрес первого элемента и есть адрес самого вектора. С нашей
точки зрения **VkPhysicalDevice** представляет собой идентификатор физического
устройства. Давайте теперь составим цикл по числу физических устройств и для
каждого из них получим больше информации.

        for (uint i = 0 ; i < NumDevices ; i++) {
            const VkPhysicalDevice& PhysDev = PhysDevices.m_devices[i];
            vkGetPhysicalDeviceProperties(PhysDev, &PhysDevices.m_devProps[i]);

Мы начинаем с получения свойств текущего устройства. *m_devProps* - это вектор
**VkPhysicalDeviceProperties**. Эта структура содержит такую информацию об
устройстве, как название, версия, ID и прочее. При помощи следующих вызовов
*printf* мы выводим на печать некоторые из этих свойств:

            printf("Device name: %s\n", PhysDevices.m_devProps[i].deviceName);
            uint32_t apiVer = PhysDevices.m_devProps[i].apiVersion;
            printf("    API version: %d.%d.%d\n", VK_VERSION_MAJOR(apiVer),
                                              VK_VERSION_MINOR(apiVer),
                                              VK_VERSION_PATCH(apiVer));

После этого мы получаем свойства всех наборов очередей, которые есть у устройства.
GPU может выполнять всего четыре вида операций:

1. Графические - 2D/3D рендер (как и OpenGL).

2. Вычисление - общий вычислительный процесс, который никак не связан с рендером.
Используется, например, для параллельных вычислений, без какого-либо отношения
к 3D.

3. Перемещение - копирование буферов и изображений.

4. Управление фрагментированной памятью, т.е. которая не смежна. Эти команды
помогают разобраться с ней.

Задачи, которые мы отправляем устройству, выполняются по очереди. Устройство
предоставвляет один или несколько наборов очередей, и каждый из них содержит
одну и более очередей. У каждого набора своя комбинация из четырёх типов
приведенных выше. Очереди в каждом наборе имеют общую функциональность.
Например, мой GPU имеет два набора: первый состоит из 16 очередей и принимает
все четыре типа команд. А второй только из одной очереди, которая поддерживает
лишь перемещение. Это полезно для архитектурно-зависимых трюков по улучшению
производительности приложения.

            uint NumQFamily = 0;

            vkGetPhysicalDeviceQueueFamilyProperties(PhysDev, &NumQFamily, NULL);

            printf("    Num of family queues: %d\n", NumQFamily);

            PhysDevices.m_qFamilyProps[i].resize(NumQFamily);
            PhysDevices.m_qSupportsPresent[i].resize(NumQFamily);

            vkGetPhysicalDeviceQueueFamilyProperties(PhysDev, &NumQFamily, &(PhysDevices.m_qFamilyProps[i][0]));

В коде выше мы получили число свойств у набора текущего устройства, изменили
размер *m_qFamilyProps* и *m_qSupportsPresent* (оба являются векторами векторов,
так что мы обязаны сначала выбрать текущее устройство), а затем мы получили и
записали в базу вектор свойств.

            for (uint q = 0 ; q < NumQFamily ; q++) {
                res = vkGetPhysicalDeviceSurfaceSupportKHR(PhysDev, q, Surface, &(PhysDevices.m_qSupportsPresent[i][q]));
                CHECK_VULKAN_ERROR("vkGetPhysicalDeviceSurfaceSupportKHR error %d\n", res);
            }

Пока мы ещё говорим про наборы очередей, давайте пройдёмся по каждому набору и
проверим, поддерживает ли он вывод на экран. **vkGetPhysicalDeviceSurfaceSupportKHR()**
принимает на вход физическое устройство, поверхность, индекс набора очередей и
возвращает флаг - может ли такая комбинация из устройства и набора выводить на
поверхность.

            uint NumFormats = 0;
            vkGetPhysicalDeviceSurfaceFormatsKHR(PhysDev, Surface, &NumFormats, NULL);
            assert(NumFormats > 0);

            PhysDevices.m_surfaceFormats[i].resize(NumFormats);

            res = vkGetPhysicalDeviceSurfaceFormatsKHR(PhysDev, Surface, &NumFormats, &(PhysDevices.m_surfaceFormats[i][0]));
            CHECK_VULKAN_ERROR("vkGetPhysicalDeviceSurfaceFormatsKHR error %d\n", res);

            for (uint j = 0 ; j < NumFormats ; j++) {
                const VkSurfaceFormatKHR& SurfaceFormat = PhysDevices.m_surfaceFormats[i][j];
                printf("    Format %d color space %d\n", SurfaceFormat.format , SurfaceFormat.colorSpace);
            }

На очереди формат поверхности. Каждая поверхность поддерживает не менее одного
формата. Формат просто определяет то, как данных используются поверхностью.
В целом, формат указывает на каналы каждого пикселя и тип канала
(float, int, ...). Например, *VK_FORMAT_R32G32B32_SFLOAT* задает три канала
(красный, зелёный и синий) из 32-х битного типа с плавающей запятой. Формат
поверхности очень важен так как он определяет то, как данные будут использоваться
или конвертироваться в различных операциях (например отображение на экран).
Для получения формата нам нужны как поверхность, так и физическое устройство
так как они могут получиться несовместимыми. Мы снова используем вектор векторов
поскольку форматов поверхностей может быть доступно сразу несколько штук.
Формат нам понадобится позже, поэтому сейчас мы записываем его в базу данных.
Теперь давайте получим свойства поверхности:

            res = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(PhysDev, Surface, &(PhysDevices.m_surfaceCaps[i]));
            CHECK_VULKAN_ERROR("vkGetPhysicalDeviceSurfaceCapabilitiesKHR error %d\n", res);

            VulkanPrintImageUsageFlags(PhysDevices.m_surfaceCaps[i].supportedUsageFlags);
        }
    }

Структура **VkSurfaceCapabilitiesKHR** описывает свойства физического устройства
в рамках конкретной поверхности. Они включают в себя минимальное и максимальное
количество изображений, которые могут входить в цепочку изображений,
минимальный и максимальный размер участка, который может быть отрендерен,
поддерживаемые повороты и прочее. Для каждой пары физического устройства и
поверхности у нас по одной структуре, все они хранятся в векторе *m_surfaceCaps*.

Ух, наконец-то мы получили всю информацию о физических устройствах! (Ещё раз,
некоторые из этих свойств зависят от выбранной поверхности). Следующий шаг в
функции *Init()* - это выбор одного из физических устройств и одной из очередей
для начала обработки. Следующая функция занимается как раз этим:

    void OgldevVulkanCore::SelectPhysicalDevice()
    {
        for (uint i = 0 ; i < m_physDevices.m_devices.size() ; i++) {

            for (uint j = 0 ; j < m_physDevices.m_qFamilyProps[i].size() ; j++) {
                VkQueueFamilyProperties& QFamilyProp = m_physDevices.m_qFamilyProps[i][j];

                printf("Family %d Num queues: %d\n", j, QFamilyProp.queueCount);
                VkQueueFlags flags = QFamilyProp.queueFlags;
                printf("    GFX %s, Compute %s, Transfer %s, Sparse binding %s\n",
                        (flags & VK_QUEUE_GRAPHICS_BIT) ? "Yes" : "No",
                        (flags & VK_QUEUE_COMPUTE_BIT) ? "Yes" : "No",
                        (flags & VK_QUEUE_TRANSFER_BIT) ? "Yes" : "No",
                        (flags & VK_QUEUE_SPARSE_BINDING_BIT) ? "Yes" : "No");

                if (flags & VK_QUEUE_GRAPHICS_BIT) {
                    if (!m_physDevices.m_qSupportsPresent[i][j]) {
                        printf("Present is not supported\n");
                        continue;
                    }

                    m_gfxDevIndex = i;
                    m_gfxQueueFamily = j;
                    printf("Using GFX device %d and queue family %d\n", m_gfxDevIndex, m_gfxQueueFamily);
                    break;
                }
            }
        }

        if (m_gfxDevIndex == -1) {
            printf("No GFX device found!\n");
            assert(0);
        }
    }

В более сложных приложениях вам могут понадобиться несколько очередей на
нескольких устройствах, но пока давайте сделаем проще. Вложенный цикл в этой
функции проходит по списку устройств и списку наборов очередей для каждого
устройства. Мы ищем устройство и очередь, которые поддерживают графические
команды и способны вывести графику на ту поверхность, для которой была заполнена
база данных. Когда мы найдем подходящее устройство и набор, мы сохраним их
индексы и выйдем из цикла. Эта пара из устройства и набора будет использоваться
на протяжении всего урока. Если подходящей пары не найдено, то приложение
будет завершено. Это означает, что система не удовлетворяем минимальным
требованиям для работы приложения.

Всё что нам осталось, это инициализировать ядро и создать логическое устройство:

    void OgldevVulkanCore::CreateLogicalDevice()
    {
        float qPriorities = 1.0f;
        VkDeviceQueueCreateInfo qInfo = {};
        qInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        qInfo.queueFamilyIndex = m_gfxQueueFamily;
        qInfo.queueCount = 1;
        qInfo.pQueuePriorities = &qPriorities;

        const char* pDevExt[] = {
            VK_KHR_SWAPCHAIN_EXTENSION_NAME
        };

        VkDeviceCreateInfo devInfo = {};
        devInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        devInfo.enabledExtensionCount = ARRAY_SIZE_IN_ELEMENTS(pDevExt);
        devInfo.ppEnabledExtensionNames = pDevExt;
        devInfo.queueCreateInfoCount = 1;
        devInfo.pQueueCreateInfos = &qInfo;

        VkResult res = vkCreateDevice(GetPhysDevice(), &devInfo, NULL, &m_device);

        CHECK_VULKAN_ERROR("vkCreateDevice error %d\n", res);

        printf("Device created\n");
    }

Vulkan разделяет понятия физического устройства, как части реальной системы, от
логического устройства как абстракции над ним. Логическое устройство - это то,
что используется в приложении для создания большей части объектов зависящих от
устройства (очереди, цепочки изображений и прочее). Такая архитектура добавляет
гибкости в управлении устройствами. Логическое устройство позволяет нам давать
доступ только к отдельным аспектам физического устройства. Например, если
физическое устройство поддерживает и графику и вычисления, то мы можем дать
доступ только к графике через логическое устройство.

Для создания устройства нам понадобится одна структура **VkDeviceCreateInfo** и
ещё одна **VkDeviceQueueCreateInfo**. *VkDeviceCreateInfo* главная часть
определения устройства. В этой структуре мы назначаем указатель на массив
расширений, которые хотим использовать. Нам нужно включить цепочки изображений,
так как они определены в расширениях, а не в ядре. Цепочка изображений - это
массив изображений поверхностей, которые могут быть нарисованы. Нам также нужен
размер массива расширений. Далее нам нужен указатель на массив структур
**VkDeviceQueueCreateInfo** (и его размер). Для каждого набора очередей, который
мы хотим использовать, потребуется одна структура **VkDeviceQueueCreateInfo**.
Эта структура содержит индекс набора очередей (который мы получили ранее в
*SelectPhysicalDevice()*), число требуемых нам очередей, и для каждой очереди
мы можем указать приоритет. В этом уроке мы не будем задавать приоритеты, т.к.
очередь у нас одна и приоритет у неё 1.0.

На этом завершается инициализация класса **OgldevVulkanCore**, но для вызова
метода *Init()* нам нужен **VulkanWindowControl** - класс, который я добавил
для декорации управления оконной поверхности. Вспомним, что эта часть не относится
к ядру Vulkan, и так как для каждой ОС требуется свой код, то я решил разделить
на классы всю работу с окнами. Сам класс является интерфейсом и определён
следующим образом:

    class VulkanWindowControl
    {
    protected:
        VulkanWindowControl() {};

        ~VulkanWindowControl() {};

    public:

        virtual bool Init(uint Width, uint Height) = 0;

        virtual VkSurfaceKHR CreateSurface(VkInstance& inst) = 0;
    };

Как вы можете заметить, этот класс крайне прост. У него нет никаких свойств.
Так как его конструктор и деструктор имеют модификатор доступа *protected*,
то нельзя создать экземпляры этого класса напрямую. Есть два публичных
метода. Один для инициализации объекта, и второй для создания поверхности Vulkan.
Таким образом для каждой ОС мы вольны в своих действиях, главное - это вернуть
объект **VkSurfaceKHR**. Таким образом, мы можем инициализировать этот класс перед
созданием **VulkanCoreObject**, но нам требуется инициализировать
**VulkanCoreObject** до вызова *CreateSurface()*. Не волнуйтесь, мы к этому ещё
вернемся при разборе функции *main()*.

Реализаций класса *VulkanWindowControl* всего две: *XCBControl* для Linux и
*Win32Control* для Windows. Сначала мы рассмотрим версию для Linux.

    class XCBControl : public VulkanWindowControl
    {
    public:
        XCBControl();

        ~XCBControl();

        virtual bool Init(uint Width, uint Height);

        virtual VkSurfaceKHR CreateSurface(VkInstance& inst);

     private:
        xcb_connection_t* m_pXCBConn;
        xcb_screen_t* m_pXCBScreen;
        xcb_window_t m_xcbWindow;
    };

Самая популярная оконная система на Linux - это, конечно же, XWindow. Она
работает в клиент - серверной архитектуре. Сервер управляет экраном, клавиатурой
и мышью. Клиентами являются приложения, которые хотят что-то вывести на экран.
Они подключаются к серверу по протоколу X11 и отправляют запросы на создание
окна, управление клавиатурой / мышью и прочее. Самыми часто встречаемыми
реализациями протокола X11 являются Xlib и XCB, и они обе поддерживаются Vulkan.
[XCB](https://en.wikipedia.org/wiki/XCB) более современная, поэтому мы будем
использовать её под Linux. **XCBControl** реализует класс **VulkanWindowControl**
используя вызовы XCB. Напомню, что целью всего этого является создание окна ОС
и подсоединение его к поверхности Vulkan. В результате Vulkan должен быть
способен рендерить в это окно. Давайте начнем с создания окна:

    void XCBControl::Init(uint Width, uint Height)
    {
        m_pXCBConn = xcb_connect(NULL, NULL);

        int error = xcb_connection_has_error(m_pXCBConn);

        if  (error) {
            printf("Error opening xcb connection error %d\n", error);
            assert(0);
        }

        printf("XCB connection opened\n");

Первое что нам потребуется сделать - это подключиться к серверу XWindow. Я
уверен что вы используете графический режим, поэтому сервер уже запущен в
фоне. *xcb_connect()* открывает подключение к серверу. Она принимает два
параметра: название сервера и указатель на желаемый номер экрана (его для
нас заполнит библиотека XCB). XWindow очень гибок в настройке. Например, он
позволяет запустить сервер на одной машине, а клиента на другой. А можно
запустить сразу несколько серверов на одной машине. Для подключения к удаленному
серверу потребуется его IP и номер экрана в специальном формате строки. А для
запуска локально достаточно передать *NULL* в оба параметра.

Мы сохраняем в классе указатель на подключение, которое возвращает
*xcb_connect()*. Функция всегда что-то возвращает, поэтому мы обязательно
проверяем наличие ошибок с помощью функции *xcb_connectionn_has_error()* как
показано выше.

        const xcb_setup_t *pSetup = xcb_get_setup(m_pXCBConn);

        xcb_screen_iterator_t iter = xcb_setup_roots_iterator(setup);

        m_pXCBScreen = iter.data;

        printf("XCB screen %p\n", m_pXCBScreen);

Сервер XWindow может управлять несколькими мониторами и запускать несколько
экранов на каждом из них. Как раз на экране и запускаются приложения. Он имеет
ширину, высоту, грубину цвета и прочие характеристики. Мы хотим получить доступ
к текущему экрану, для чего нам потребуются два действия. Первое - это
использовать функцию *xcb_get_setup()* для доступа к структуре *xcb_setup_t*
с данными о соединении. В ней содержится большое количество информации о
сервере. Среди прочего там есть список экранов. Для доступа к этому списку мы
создаем итератор с помощью функции *xcb_setup_roots_iterator()*. В сложных
приложениях тут должен быть код, который пробегает по списку экранов в поиске
подходящего для приложения. А мы просто возьмём первый в списке. Экран можно
получить следующим образом:

        m_xcbWindow = xcb_generate_id(m_pXCBConn);

Теперь мы готовы к созданию окна. Первым шагом мы генерируем *XID* - беззнаковое
целое число, идентификатор всех ресурсов XWindow. Когда клиент подсоединяется к
серверу, последний выделяет подмножество XID для этого клиента. Когда клиент
хочет создать некоторый объект на сервере, он выделяет себе XID из разрешенного
ему промежутка. Последующие вызовы функций могут использовать полученный XID.
Это довольно интересный подход. Обычно сервер говорит "эй, вот тебе новый объект и
его номер XYZ". А здесь клиент говорит "слушай, сервер, я хочу создать новый
объект и вот его номер". *xcb_generate_id()* генерирует XID для окна, а мы
сохраняем его в свойство *m_xcbWindow*.

        xcb_create_window(m_pXCBConn,             // соединение с сервером XWindow
          XCB_COPY_FROM_PARENT,                   // глубина цвета
          m_xcbWindow,                            // XID нового окна
          m_pXCBScreen->root,                     // родительское окно
          0,                                      // координата X
          0,                                      // координата Y
          Width,                                  // ширина окна
          Height,                                 // высота окна
          0,                                      // ширина границы
          XCB_WINDOW_CLASS_INPUT_OUTPUT,          // класс окна, не смог найти документации
          m_pXCBScreen->root_visual,              // определяет отображения цвета
          0,
          0);

Функция *xcb_create_window()*, которая создает окно, принимает, ни много ни
мало, 13 параметров. Я добавил немного комментариев к ним, большая часть из
них очевидны. Больше мы к этому не возвращаемся. Поищите информацию в интернете,
если оно вам надо.

        xcb_map_window(m_pXCBConn, m_xcbWindow);
        xcb_flush (m_pXCBConn);
    }

Чтобы сделать окно видимым мы должны его отобразить и заставить сервер вывести
буфер на экран. Вот этим два вызова выше и занимаются.

    VkSurfaceKHR XCBControl::CreateSurface(VkInstance& inst)
    {
        VkXcbSurfaceCreateInfoKHR surfaceCreateInfo = {};
        surfaceCreateInfo.sType = VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR;
        surfaceCreateInfo.connection = m_pXCBConn;
        surfaceCreateInfo.window = m_xcbWindow;

        VkSurfaceKHR surface;

        VkResult res = vkCreateXcbSurfaceKHR(inst, &surfaceCreateInfo, NULL, &surface);
        CHECK_VULKAN_ERROR("vkCreateXcbSurfaceKHR error %d\n", res);

        return surface;
    }

Последняя функция из класса **XCBControl**, на которую мы обратим внимание, - это
*CreateSurface()*. По сути это декоратор функции Vulkan *vkCreateXcbSurfaceKHR()*.
Мы заполняем структуру **VkXcbSurfaceCreateInfoKHR** указателем на соединение
с сервером XWindow и созданным ранее окном. В ответ мы получим поверхность Vulkan,
которую сразу же передаем назад вызвавшей функции.

Давайте теперь рассмотрим аналогичный класс для Windows:

    class Win32Control : public VulkanWindowControl
    {
    public:
        Win32Control(const char* pAppName);

        ~Win32Control();

        virtual void Init(uint Width, uint Height);

        virtual VkSurfaceKHR CreateSurface(VkInstance& inst);

     private:

        HINSTANCE   m_hinstance;
        HWND        m_hwnd;
        std::wstring m_appName;
    };

Как вы видите, интерфейс для обеих ОС очень похож. По факту, *Init()* и
*CreateSurface()* идентичны так как они виртуальные функции. Мы также
добавили приватные свойства для записи специфических для Windows данных -
*HINSTANE* и *HWND*.

    Win32Control::Win32Control(const char* pAppName)
    {
        m_hinstance = GetModuleHandle(NULL);;
        assert(m_hinstance);
        m_hwnd = 0;
        **std::string s(pAppName)**;
        m_appName = **std::wstring(s.begin(), s.end())**;
    }

Выше показан конструктор класса **Win32Control**, который я привожу только для
того, что бы вы знали как преобразовывается название окна из массива букв в
*std::wstring*. Мы делаем это для функции *CreateWindowEx()*, которой название
окна требуется в виде типа *LPCTSTR*. Стандартный класс *wstring* нам в этом
пригодится.

    LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
    {
        return DefWindowProc(hwnd, uMsg, wParam, lParam);
    }

    void Win32Control::Init(uint Width, uint Height)
    {
        WNDCLASSEX wndcls = {};

        wndcls.cbSize = sizeof(wndcls);
        wndcls.lpfnWndProc = WindowProc;
        wndcls.hInstance = m_hinstance;
        wndcls.hbrBackground = (HBRUSH)GetStockObject(WHITE_BRUSH);
        wndcls.lpszClassName = L"ogldev";

        if (!RegisterClassEx(&wndcls)) {
            DWORD error = GetLastError();
            OGLDEV_ERROR("RegisterClassEx error %d", error);
        }

        m_hwnd = CreateWindowEx(0,
                                L"ogldev",                        // название
                                m_appName.c_str(),
                                WS_OVERLAPPEDWINDOW | WS_VISIBLE, // стиль окна
                                100, 100,                         // начальное положение
                                Width,
                                Height,
                                NULL,
                                NULL,
                                m_hinstance,
                                NULL);

        if (m_hwnd == 0) {
            DWORD error = GetLastError();
            OGLDEV_ERROR("CreateWindowEx error %d", error);
        }

        ShowWindow(m_hwnd, SW_SHOW);
    }

Код выше, который создает окно, я нашел на MSDN, поэтому я не буду сильно
вдаваться в детали. Мы регистрируем окно через *RegisterClassEx()*. Окно будет
иметь связь с функцией *WindowProc()* - обработчиком событий. Прямо сейчас мы
используем стандартный обработчик, но в следующих уроках мы добавим больше
деталей. Окно создается функцией *CreateWindowEx()* и, наконец, отображается
через *ShowWindow()*.

    VkSurfaceKHR Win32Control::CreateSurface(VkInstance& inst)
    {
        VkWin32SurfaceCreateInfoKHR surfaceCreateInfo = {};
        surfaceCreateInfo.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
        surfaceCreateInfo.hinstance = m_hinstance;
        surfaceCreateInfo.hwnd = m_hwnd;

        VkSurfaceKHR surface;

        VkResult res = vkCreateWin32SurfaceKHR(inst, &surfaceCreateInfo, NULL, &surface);
        CHECK_VULKAN_ERROR("vkCreateXcbSurfaceKHR error %d\n", res);

        return surface;
    }

*CreateSurface()* тоже очень похожа на аналог для Linux. Параметр
*surfaceCreateInfo* здесь представляет собой экземпляр (и, конечно же,
обработчики windows имеют другие типы).

    int main(int argc, char** argv)
    {
        VulkanWindowControl* pWindowControl = NULL;
    #ifdef WIN32
        pWindowControl = new Win32Control(pAppName);
    #else
        pWindowControl = new XCBControl();
    #endif
        pWindowControl->Init(WINDOW_WIDTH, WINDOW_HEIGHT);

        OgldevVulkanCore core("tutorial 50");
        core.Init(pWindowControl);

        return 0;
    }

Наконец мы подошли к связыванию всего кода в функции *main()*. Если есть желание,
то вы можете начать отсюда и постепенно добавлять блоки кода, проверяя какие
значения будет для них возвращать Vulkan. Всё в этой функции уже было подробно
рассмотрено. Мы выделяем память для реализации класса **VulkanWindowControl**
(для Linux или Windows), а затем создает и инициализируем объект
**OgldevVulkanCore**. Теперь у нас есть связанная с окном ОС поверхность Vulkan,
экземпляр Vulkan, устройство и база данных со всеми физическими устройствами.

Надеюсь что вам этот урок пригодился. Кстати, вместе с ним полагается футболка
с надписью "Я написал тону кода на Vulkan, а получил пустое окно". Действительно,
мы проделали большой путь, а ничего так и не отрендерели. Но не отчаивайтесь.
У нас есть базовая структура с несколькими объектами ядра Vulkan. В следующем
уроке мы продолжим работать над ним, так что не переключайтесь.
