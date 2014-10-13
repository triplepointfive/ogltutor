---
title: Урок 44 - GLFW
---

В первом уроке мы выяснили, что OpenGL это API, которое относится исключительно к графике — в него не входят функции по созданию окон; за это отвечают сторонние API (GLX, WGL и другие). Для удобства мы использовали GLUT для обработки окон, помимо того, это позволяло легко портировать уроки для различных ОС. До сегодняшнего дня мы использовали исключительно GLUT. Теперь рассмотрим другую популярную библиотеку, выполняющую те же функции, названную [GLFW](www.glfw.org). Одно главное отличие заключается в том, что GLFW современная и находится в активной разработке, в то время как GLUT старее и почти не разрабатывается. GLFW имеет много особенностей, которые можно найти на главной странице библиотеки.

Поскольку в этом уроке нет математического раздела, мы можем сразу перейти к обзору кода. Я выделил общее API по настройке окна и обработке пользовательского ввода, а также разделил использование библиотек по файлам glut_backend.h и glut_backend.cpp. Вы можете легко переключаться между GLUT и GLFW, что дает гибкость в использовании для будущих уроков.

Установка GLFW (от root):

Fedora Core: yum install glfw glfw-devel

Ubuntu: apt-get install libglfw3 libglfw3-dev

Остальные дистрибутивы Linux также предоставляют GLFW. В противном случае, мы можете скачать исходный код с сайта GLFW и собрать самостоятельно.
Если вы пользуетесь Windows просто используйте заголовочные файлы и библиотеки GLFW, которые я приложил к [исходному коду](http://ogldev.atspace.co.uk/ogldev-source.zip). Урок должен легко скомпилироваться без каких-либо изменений (сообщите мне, если возникнут проблемы...).

Для того, что бы использовать GLFW вы должны сообщить компилятору где находятся файлы библиотеки. Для систем Linux я советую использовать программу pkg-config:

> pkg-config --cflags --libs glfw3

Флаг *--cflags* выводит требуемые флаги для GCC, которые необходимы для компиляции, а флаг *--libs* выводит всё необходимое для линковки. Я использую эти флаги в проекте Netbeans, который я использую под Linux, так же вы можете использовать их при написании своего makefile. Если вы используете системы автоматической сборки наподобие autotools, cmake и scons, вам стоит изучить документацию для подробностей.

## [Прямиком к коду!](https://github.com/triplepointfive/ogldev/tree/master/tutorial44)

> ogldev_glfw_backend.cpp:24

    #define GLFW_DLL
    #include

Так подключается GLFW. Макрос *GLFW_DLL* требуется для Windows для использования GLFW в качестве DLL.

> ogldev_glfw_backend.cpp:168

    void GLFWBackendInit(int argc, char** argv, bool WithDepth, bool WithStencil)
    {
        sWithDepth = WithDepth;
        sWithStencil = WithStencil;

        if (glfwInit() != 1) {
            OGLDEV_ERROR("Error initializing GLFW");
            exit(1);
        }

        int Major, Minor, Rev;

        glfwGetVersion(&Major, &Minor, &Rev);

        printf("GLFW %d.%d.%d initialized\n", Major, Minor, Rev);

        glfwSetErrorCallback(GLFWErrorCallback);
    }

Инициализация GLFW крайне проста. Заметим, что хотя параметры *argc/argv* не используются, мы передаем их что бы аналогичная функция для GLUT имела тот же набор параметров. Помимо инициализации мы также выводим информацию о версии библиотеки и задаем функнцию обработки ошибок. Если что-то пойдет не так мы напечатаем сообщение ошибки и выйдем из приложения.

> ogldev_glfw_backend.cpp:195

    bool GLFWBackendCreateWindow(uint Width, uint Height, bool isFullScreen, const char* pTitle)
    {
        GLFWmonitor* pMonitor = isFullScreen ? glfwGetPrimaryMonitor() : NULL;

        s_pWindow = glfwCreateWindow(Width, Height, pTitle, pMonitor, NULL);

        if (!s_pWindow) {
            OGLDEV_ERROR("error creating window");
            exit(1);
        }

        glfwMakeContextCurrent(s_pWindow);

        // Must be done after glfw is initialized!
        glewExperimental = GL_TRUE;
        GLenum res = glewInit();
        if (res != GLEW_OK) {
            OGLDEV_ERROR((const char*)glewGetErrorString(res));
            exit(1);
        }

        return (s_pWindow != NULL);
    }

В функции выше мы создаем окно и выполняем прочую инициализацию. Первые 3 параметра для  [glfwCreateWindow](http://www.glfw.org/docs/latest/group__window.html#ga5c336fddf2cbb5b92f65f10fb6043344) очевидны. Четвертый параметр указывает используемый монитор. *GLFWmonitor* представляет собой физический монитор. GLFW поддерживает несколько мониторов одновременно и для таких случаев функция [glfwGetMonitors](http://www.glfw.org/docs/latest/group__monitor.html#ga3fba51c8bd36491d4712aa5bd074a537) возвращает список доступных мониторов. Если передать нулевой указатель, то мы получим обыкновенное окно; если передать указатель на текущий монитор (экран по умолчанию можно получить с помощью [glfwGetPrimaryMonitor](http://www.glfw.org/docs/latest/group__monitor.html#ga721867d84c6d18d6790d64d2847ca0b1)) будет полноэкранное окно. Очень просто. Пятый и последний параметр используются для обмена содержимым, что не входит в данный урок.

Перед использованием функций GL мы должны пометить окно текущим. Для этого используем комманду  [glfwMakeContextCurrent](http://www.glfw.org/docs/latest/group__context.html#ga1c04dc242268f827290fe40aa1c91157). Наконец, инициализируем GLEW.

> ogldev_glfw_backend.cpp:238

    while (!glfwWindowShouldClose(s_pWindow)) {
        // OpenGL API calls go here...
        glfwSwapBuffers(s_pWindow);
        glfwPollEvents();
    }

В отличие от GLUT, GLFW не имеет собственной функции главного цикла. Поэтому, мы создаём её используя код выше, являющийся частью функции-обертки GLFWBackendRun(). *s_pWindow* это указатель на окно GLFW, созданное ранее функцией glfwCreateWindow(). Для того, что бы передать приложению сигнал об окончании цикла используется функция [glfwSetWindowShouldClose](http://www.glfw.org/docs/latest/group__window.html#ga24e02fbfefbb81fc45320989f8140ab5).

> ogldev_glfw_backend.cpp:122

    static void KeyCallback(GLFWwindow* pWindow, int key, int scancode, int action, int mods)
    {
    }


    static void CursorPosCallback(GLFWwindow* pWindow, double x, double y)
    {
    }


    static void MouseCallback(GLFWwindow* pWindow, int Button, int Action, int Mode)
    {
    }

    static void InitCallbacks()
    {
        glfwSetKeyCallback(s_pWindow, KeyCallback);
        glfwSetCursorPosCallback(s_pWindow, CursorPosCallback);
        glfwSetMouseButtonCallback(s_pWindow, MouseCallback);
    }

Выше мы видим инициализацию функций для обработки событий мыши и клавиатуры. Если вы заинтересованны в использовании только GLFW, можете изучить документацию по [ссылке](http://www.glfw.org/docs/latest/group__input.html) о значениях Button, Action и Mode. Для своих уроков я создал набор перечислений для описания различных кнопок мыши и клавиатуры и перевожу GLFW на эти перечисления. Аналогично я сделал для GLUT. Такой подход дает общность, которая позволяет одному коду приложения быстро переключаться между библиотеками окон (для подробностей смотрите реализацию функций выше).

> ogldev_glfw_backend.cpp

    void GLFWBackendTerminate()
    {
        glfwDestroyWindow(s_pWindow);
        glfwTerminate();
    }

Так мы останавливаем приложение GLFW. Сначала мы уничтожаем окно и отключаем библиотеку и освобождаем все используемые ей ресурсы. После этого вызовы к GLFW делать нельзя, поэтому это и является последней функцией (затрагивающих графику) в приложении.

> ogldev_backend.h

    enum OGLDEV_BACKEND_TYPE {
        OGLDEV_BACKEND_TYPE_GLUT,
        OGLDEV_BACKEND_TYPE_GLFW
    };

    void OgldevBackendInit(OGLDEV_BACKEND_TYPE BackendType, int argc, char** argv, bool WithDepth, bool WithStencil);

    void OgldevBackendTerminate();

    bool OgldevBackendCreateWindow(uint Width, uint Height, bool isFullScreen, const char* pTitle);

    void OgldevBackendRun(ICallbacks* pCallbacks);

    void OgldevBackendLeaveMainLoop();

    void OgldevBackendSwapBuffers();

Я создал новый интерфейс, который мы видим в заголовочном файле выше. Эти функции заменяют специфический код для GLUT, который мы использовали ранее. Они реализованы в ogldev_backend.cpp и используют либо GLUT либо GLFW. Вы выбираете библиотеку через OgldevBackendInit(), а дальше ничего не обычного.

Поскольку в этом уроке для отображения не было добавлено ничего нового, я использую модель Sponza, которая очень популярна в 3D сообществе для тестирования алгоритмов глобального освещения.
