---
title: Урок 48 - Пользовательский интерфейс с Ant Tweak Bar
---

В этом уроке мы на время собираемся покинуть 3D и сконцентрировать наше внимание
на добавлении чего-то полезного и практичного для наших программ. Мы научимся создавать
пользовательский интерфейс, который поможет в настройке различных значений.
Библиотека, которую мы собираемся использовать, называется *Ant Tweak Bar* (или ATB),
которая расположена на [anttweakbar.sourceforge.net](http://anttweakbar.sourceforge.net/).
Существует немало настроек, и если вы захотите, то найдете гору обсуждений и мнений
по поводу каждой. Кроме OpenGL, ATB также поддерживает DirectX 9/10/11, поэтому
если вы хотите, что бы ваш интерфейс был портируемым, то это большое преимущество.
Библиотека кажется мне очень удобной и легкой в освоении. И я надеюсь вы разделите
это мнение. Ну что ж, приступим.

**<font color='red'>
Важно: только когда я уже заканчивал этот урок, я заметил, что ATB больше не разрабатывается. Официальный сайт ещё жив,
но автор предупреждает, что больше не будет активно его поддерживать. После небольших размышлений, я всё-таки решил опубликовать
этот урок. Библиотека для меня оказалась крайне удобной и я продолжу её использовать. Если вы ищите что-то подобное по
функционалу, но обязательно находящееся в активной разработке, то можете поискать альтернативу, хотя я считаю, что большинству
должно хватить и того, что уже есть. Поскольку это открытое программное обеспечение, то всегда есть шанс найти нового разработчика.
</font>**

### Установка

Первое что нам нужно сделать - это установить ATB. Вы можете скачать [zip архив](https://sourceforge.net/projects/anttweakbar/files/latest/download?source=dlp)
с сайта ATB (на момент публикации этого урока версию 1.6), который содержит почти всё что вам нужно,
либо используйте файлы, которые я прикладываю ко всем урокам. Если вы пойдете путем с сайтом, то
распакуйте архив и переложите файл *AntTweakBar.h* из католога *include* в тот католог, в котором
он будет виден проекту. На Linux я бы рекомендовал положить его в /usr/local/include (потребуется
доступ от суперпользователя). В пакете с уроками этот файл находится в катологе Include/ATB.

Теперь о файлах библиотеки.

Если вы пользуетесь Windows, то ничего сложного. Официальный архив содержит каталог lib с файлами
AntTweakBar.dll и AntTweakBar.lib (и ещё одна такая же пара для архитектуры 64). Потребуется добавить
lib файл в проект на стадии линковки, а dll файл должен быть доступным для исполняемого файла в
локальный директории, либо в катологе Windows\System32. На Linux потребуется зайти в католог src
и выполнить команду *make* для того, что бы собрать библиотеку. В результате получатся файлы
libAntTweakBar.a, libAntTweakBar.so и libAntTweakBar.so.1. Я рекомендую скопировать эти файлы в
каталог /usr/local/lib и сделать их доступными для всех. Архив с исходным кодом для этого урока
содержит всё необходимое для обеих систем.

### Интеграция

Что бы начать использовать ATB добавте в ваш код следующий заголовочный файл:

    #include <AntTweakBar.h>

Если вы используете мой проект Netbeans, то каталог Include/ATB уже добавлен в качестве
источника заголовочных файлов. В противном случае убедитесь, что система сборки видит этот файл.

Для линковки с библиотекой:
- Windows: добавьте *AntTweakBar.lib* в ваш проект .
- Linux: добавьте *-lAntTweakBar* в систему сборки, а так же проверьте, что сами файлы находятся в /usr/local/lib.

Ещё раз напомню, что если вы используете мои проекты Visual Studio или Netbeans, то вся работа уже сделана за вас.

### Инициализация

Для инициализации ATB понадобится вызов:

    TwInit(TW_OPENGL, NULL);

а для случая с Core Profile используйте:

    TwInit(TW_OPENGL_CORE, NULL);

Для этого урока я создал класс-обертку над ATB, который инкапсулирует часть функционала
библиотеки и немного упрощает интеграцию (этот класс находится в каталоге Common).
Для инициализации ATB с помощью класса используйте код наподобии:

    ATB m_atb;
    if (!m_atb.Init()) {
        // error
        return false;
    }

### Обработка Событий

ATB предоставляет целый набор разнообразных виджетов. В некоторых вы можете просто вводить новые значения. А есть и более
сложные, где можно использовать мышку для изменения значений. Как следствие, ATB должен получать события клавиатуры и мыши.
Для этой цели используются несколько коллбэков, и для каждой графической библиотеки (glut, glfw, SDL, ...) ATB предоставляет
свой набор. Если ваш фреймворк использует одну из этих библиотек, то вы можете просто вызывать каллбэки ATB внутри
собственных. Пример приведен на сайте ATB. Поскольку OGLDEV поддерживает как glut так и glfw, я покажу как я интегрировал
каллбэки в мой фреймворк таким образом, что обе библиотеки поддерживаются единым образом. Посмотрите на следующие функции
из класса ATB:

    bool ATB::KeyboardCB(OGLDEV_KEY OgldevKey)
    {
          int ATBKey = OgldevKeyToATBKey(OgldevKey);

          if (ATBKey == TW_KEY_LAST) {
                return false;
          }

          return (TwKeyPressed(ATBKey, TW_KMOD_NONE) == 1);
    }


    bool ATB::PassiveMouseCB(int x, int y)
    {
          return (TwMouseMotion(x, y) == 1);
    }


    bool ATB::MouseCB(OGLDEV_MOUSE Button, OGLDEV_KEY_STATE State, int x, int y)
    {
          TwMouseButtonID btn = (Button == OGLDEV_MOUSE_BUTTON_LEFT) ? TW_MOUSE_LEFT : TW_MOUSE_RIGHT;
          TwMouseAction ma = (State == OGLDEV_KEY_STATE_PRESS) ? TW_MOUSE_PRESSED : TW_MOUSE_RELEASED;

          return (TwMouseButton(ma, btn) == 1);
    }

По сути эти функции - обертки над каллбэками ATB. Они переводят внутренние типы OGLDEV в типы ATB и
передают их дальше в ATB. Функции возвращают true если ATB обработал событие (и можно просто
проигнорировать) и false если нет (так что стоит обратить на это событие внимание). Вот пример того
как я добавил эти функции в каллбэки этого урока:

    virtual void KeyboardCB(OGLDEV_KEY OgldevKey, OGLDEV_KEY_STATE OgldevKeyState)
    {
          if (OgldevKeyState == OGLDEV_KEY_STATE_PRESS) {
                if (m_atb.KeyboardCB(OgldevKey)) {
                      return;
                }
          }

          switch (OgldevKey) {
             .
             .
             .
              default:
                     m_pGameCamera->OnKeyboard(OgldevKey);
          }
    }


    virtual void PassiveMouseCB(int x, int y)
    {
           if (!m_atb.PassiveMouseCB(x, y)) {
                  m_pGameCamera->OnMouse(x, y);
           }
    }


    virtual void MouseCB(OGLDEV_MOUSE Button, OGLDEV_KEY_STATE State, int x, int y)
    {
           m_atb.MouseCB(Button, State, x, y);
    }

Если вы не знакомы с фреймворком OGLDEV, то код выше, возможно, не имеет для вас никакого смысла,
поэтому обязательно ознакомтесь с предыдущими уроками, что бы понять как всё устроено.
Каждый урок - это всего лишь класс, который наследует *ICallbacks* и *OgldevApp*. ICallbacks
предоставляет (не удивительно) каллбэки, вызываемые бэкендом (glut или glfw). Сначала мы
передаём события ATB, и если он их не обработал, то передаём их приложению (конкретно объекту - камере).

### Создание интерфейса

Вам понадобится создать как минимум один экземпляр класса *TwNewBar*, представляющего
собой окно с набором виджетов, позволяющих ATB взаимодействовать с приложением:

    TwBar *bar = TwNewBar("OGLDEV");

Строка в скобках - это название окна.

### Draw the tweak bar

In order for the tweak bar to appear in your OpenGL window there must be a call present
to the TwDraw() function in the render loop. The ATB website provides the following
generic render loop as an example:

    // main loop
    while( ... )
    {
          // clear the frame buffer
          // update view and camera
          // update your scene
          // draw your scene

          TwDraw();  // draw the tweak bar(s)

          // present/swap the frame buffer
    } // end of main loop

I placed a call to TwDraw() in the beginning of OgldevBackendSwapBuffers() (ogldev_backend.cpp:97).
This function is called at the end of every main render function and is a good place
to integrate TwDraw() into the framework.

### Adding widgets

The above is everything you need to basically have ATB up and running in your application.
Your ATB bar should now look like this:

![](/images/48/atb1.jpg)

From now on what we need to do is to add widgets and link them to our application
so that they can be used to tweak parameters of our code.

Let's add a drop down box. In this tutorial I will use it to select the mesh to
be displayed. We need to use the TwEnumVal structure provided by ATB in order to create
a list of available items in the drop down box. That structure is made of pairs of integer
and a char array. The integer is an identifier for the drop down item and the
char array is the name to be displayed. Once the item list is created as an array of TwEnumVal
structs we create a TwType object using the TwDefineEnum function. TwType is an enum of a few
parameter types that ATB understands (color, vectors, etc) but we can add user defined types
to support our specific needs. Once our TwType is ready we can use TwAddVarRW to link it
to the tweak bar. TwAddVarRW() also takes an address of an integer where ATB will place
the current selection in the drop down box. We can then use that integer to change stuff
in our application (the mesh to be displayed in our case).

        // Create an internal enum to name the meshes
        typedef enum { BUDDHA, BUNNY, DRAGON } MESH_TYPE;
    // A variable for the current selection - will be updated by ATB
    MESH_TYPE m_currentMesh = BUDDHA;
    // Array of drop down items
    TwEnumVal Meshes[] = { {BUDDHA, "Buddha"}, {BUNNY, "Bunny"}, {DRAGON, "Dragon"}};
    // ATB identifier for the array
    TwType MeshTwType = TwDefineEnum("MeshType", Meshes, 3);
    // Link it to the tweak bar
    TwAddVarRW(bar, "Mesh", MeshTwType, &m_currentMesh, NULL);

The result should look like this:

![](/images/48/atb2.jpg)

We can add a seperator using the following line:


        // The second parameter is an optional name
    TwAddSeparator(bar, "", NULL);

Now we have:

![](/images/48/atb3.jpg)

Let's see how we can link our camera so that its position and direction will always
be displayed. Until now you are probably already used to printing the current
camera parameters so that they can be reused later but displaying them in the UI
is much nicer. To make the code reusable I've added the function AddToATB() to the camera
class. It contains three calls to ATB functions. The first call just uses TwAddButton()
in order to add a string to the tweak bar. TwAddButton() can do much more and we will see
an example later on. Then we have TwAddVarRW() that adds a read/write variable and
TwAddVarRO() that adds a read-only variable. The read/write variable we use here
is simply the position of the camera and the UI can be used to modify this and
have it reflected in the actual application. Surprisingly, ATB does no provide an
internal TwType for an array of three floats so I created one to be used by
the framework:

> (ogldev_atb.cpp:38)


        TwStructMember Vector3fMembers[] = {
              { "x", TW_TYPE_FLOAT, offsetof(Vector3f, x), "" },
              { "y", TW_TYPE_FLOAT, offsetof(Vector3f, y), "" },
              { "z", TW_TYPE_FLOAT, offsetof(Vector3f, z), "" }
        };

        TW_TYPE_OGLDEV_VECTOR3F = TwDefineStruct("Vector3f", Vector3fMembers, 3, sizeof(Vector3f), NULL, NULL);

We can now use TW_TYPE_OGLDEV_VECTOR3F whenever we want to add a widget to tweak a
vector of 3 floats. Here's the complete AddToATB() function:


    void Camera::AddToATB(TwBar* bar)
    {
          TwAddButton(bar, "Camera", NULL, NULL, "");
          TwAddVarRW(bar, "Position", TW_TYPE_OGLDEV_VECTOR3F, (void*)&m_pos, NULL);
          TwAddVarRO(bar, "Direction", TW_TYPE_DIR3F, &m_target, " axisz=-z ");
    }

We have used the provided TW_TYPE_DIR3F as the parameter type that displays an array
of 3 floats using an arrow. Note the addition of 'axisz=-z' as the last parameter
of TwAddVarRO(). Many ATB functions take a string of options in the last parameter. This allows
modifying the internal behavior of the function. axisz is used to change from right handed system (ATB default)
to left handed system (OGLDEV default). There's a lot of additional options available that
I simply cannot cover. You can find them <a href="http://anttweakbar.sourceforge.net/doc/tools:anttweakbar:varparamsyntax">here</a>.

Here's how the tweak bar looks with the camera added:

![](/images/48/atb4.jpg)


You are probably spending a lot of time playing with the orientation of your meshes. Let's add
something to the tweak bar to simplify that. The solution is a visual quaternion that
can be used to set the rotation of a mesh. We start by adding a local Quaternion variable (see ogldev_math_3d.h for
the definition of that struct):

    Quaternion g_Rotation = Quaternion(0.0f, 0.0f, 0.0f, 0.0f);

We then link the quaternion variable to the tweak bar using the parameter type TW_TYPE_QUAT4F:

    TwAddVarRW(bar, "ObjRotation", TW_TYPE_QUAT4F, &g_Rotation, " axisz=-z ");

Again, we need to change from right handed to left handed system. Finally the quaternion
is converted to degrees:


    m_mesh[m_currentMesh].GetOrientation().m_rotation = g_Rotation.ToDegrees();

The rotation vector can now be used to orient the mesh and generate the WVP matrix for it:


    m_pipeline.Orient(m_mesh[m_currentMesh].GetOrientation());

Our tweak bar now looks like this:

![](/images/48/atb5.jpg)

Now let's add a check box. We will use the check box to toggle between automatic
rotation of the mesh around the Y-axis and manual rotation (using the quaternion we
saw earlier). First we make an ATB call to add a button:



    TwAddButton(bar, "AutoRotate", AutoRotateCB, NULL, " label='Auto rotate' ");


The third parameter is a callback function which is triggered when the check box
is clicked and the fourth parameter is a value to be transfered as a parameter to
the callback. I don't need it here so I've used NULL.



    bool gAutoRotate = false;

    void TW_CALL AutoRotateCB(void *p)
    {
              gAutoRotate = !gAutoRotate;
    }


You can now use gAutoRotate to toggle between automatic and manual rotations.

Here's how the tweak bar looks like:

![](/images/48/atb6.jpg)

Another useful widget that we can add is a read/write widget for controlling the speed
of rotation (when auto rotation is enabled). This widget provides multiple ways to control
its value:



    TwAddVarRW(bar, "Rot Speed", TW_TYPE_FLOAT, &m_rotationSpeed,
                         " min=0 max=5 step=0.1 keyIncr=s keyDecr=S help='Rotation speed (turns/second)' ");


 The first four parameters are obvious. We have the pointer to the tweak bar, the string to display, the type of the parameter and the
 address where ATB will place the updated value. The interesting stuff comes in the option string at the end. First we
 limit the value to be between 0 and 5 and we set the increment/decrement step to 0.1. We set the keys 's' and 'd' to be shortcuts
 to increment or decrement the value, respectively. When you hover over the widget you can see the shortcuts in the bottom of the tweak
 bar. You can either type in the value directly, use the shortcut keys, click on the '+' or '-' icons on the right or use the lever to
 modify the value (click on the circle to bring up the rotation lever). Here's the bar with this widget:

![](/images/48/atb7.jpg)

In all of the tutorials there is usually at least one light source so it makes sense to add some code that will allow us to
easily hook it up to the tweak bar so we can play with it parameters. So I went ahead and added the following methods to the
various light source classes:



    void BaseLight::AddToATB(TwBar *bar)
    {
          std::string s = Name + ".Color";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_COLOR3F, &Color, NULL);
          s = Name + ".Ambient Intensity";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_FLOAT, &AmbientIntensity, "min=0.0 max=1.0 step=0.005");
          s = Name + ".Diffuse Intensity";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_FLOAT, &DiffuseIntensity, "min=0.0 max=1.0 step=0.005");
    }


    void DirectionalLight::AddToATB(TwBar *bar)
    {
          BaseLight::AddToATB(bar);
          std::string s = Name + ".Direction";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_DIR3F, &Direction, "axisz=-z");
    }


    void PointLight::AddToATB(TwBar *bar)
    {
          BaseLight::AddToATB(bar);
          std::string s = Name + ".Position";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_OGLDEV_VECTOR3F, &Position, "axisz=-z");
          s = Name + ".Attenuation";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_OGLDEV_ATTENUATION, &Attenuation, "");
    }


    void SpotLight::AddToATB(TwBar *bar)
    {
          PointLight::AddToATB(bar);
          std::string s = Name + ".Direction";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_DIR3F, &Direction, "axisz=-z");
          s = Name + ".Cutoff";
          TwAddVarRW(bar, s.c_str(), TW_TYPE_FLOAT, &Cutoff, "");
    }

Note that 'Name' is a new string memeber of the BaseLight class that must be set before AddToATB() function
is called on the light object. It represents the string that will be displayed in the tweak bar for that light.
If you plan on adding multiple lights you must make sure to pick up unique names for them. AddToATB() is a virtual
function so the correct instance according to the concrete class is always called. Here's the bar
with a directional light source:

![](/images/48/atb8.jpg)

The last thing that I want to demonstrate is the ability to get and set various parameters that control the behaviour
of the tweak bar. Here's an example of setting the refresh rate of the bar to one tenth of a second:

    float refresh = 0.1f;
    <b>TwSetParam</b>(bar, NULL, "refresh", TW_PARAM_FLOAT, 1, &refresh);

Since moving the mouse to the tweak bar means that the camera also moves I made the key 'a' automatically move the
mouse to the center of the tweak bar without touching the camera. I had to read the location and size of the tweak bar
in order to accomplish that so I used TwGetParam() in order to do that:

    virtual void KeyboardCB(OGLDEV_KEY OgldevKey)
    {
              if (!m_atb.KeyboardCB(OgldevKey)) {
                    switch (OgldevKey) {
                          case OGLDEV_KEY_A:
                          {
                                int Pos[2], Size[2];
                                <b>TwGetParam</b>(bar, NULL, "position", TW_PARAM_INT32, 2, Pos);
                                <b>TwGetParam</b>(bar, NULL, "size", TW_PARAM_INT32, 2, Size);
                                OgldevBackendSetMousePos(Pos[0] + Size[0]/2, Pos[1] + Size[1]/2);
                                break;
                          }
