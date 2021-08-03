/* modeset - simple Lua binding to the modeset functionallity
 * Original code by David Rheinsberg <david.rheinsberg@gmail.com> (Dedicated to
 * the Public Domain.) */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

#include "lua.h"
#include "lauxlib.h"
#include "ldb.h"

#define LUA_T_PUSH_S_N(S, N) lua_pushstring(L, S); lua_pushnumber(L, N); lua_settable(L, -3);
#define LUA_T_PUSH_S_S(S, S2) lua_pushstring(L, S); lua_pushstring(L, S2); lua_settable(L, -3);
#define LUA_T_PUSH_S_CF(S, CF) lua_pushstring(L, S); lua_pushcfunction(L, CF); lua_settable(L, -3);





/* ----- TODO check headers from glesgui ----- */
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <time.h>

#include <xf86drm.h>
#include <xf86drmMode.h>
#include <gbm.h>

#define GL_GLEXT_PROTOTYPES 1
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#include <GL/gl.h>


#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <assert.h>

/* ---------- */

#define ARRAY_SIZE(arr) (sizeof(arr) / sizeof((arr)[0]))

static struct {
	EGLDisplay display;
	EGLConfig config;
	EGLContext context;
	EGLSurface surface;
	GLuint program;
	GLint modelviewmatrix, modelviewprojectionmatrix, normalmatrix;
	GLuint vbo;
	GLuint positionsoffset, colorsoffset, normalsoffset;
} gl;

static struct {
	struct gbm_device *dev;
	struct gbm_surface *surface;
} gbm;

static struct {
	int fd;
	drmModeModeInfo *mode;
	uint32_t crtc_id;
	uint32_t connector_id;
} drm;

struct drm_fb {
	struct gbm_bo *bo;
	uint32_t fb_id;
};

struct gbm_bo *bo;
struct drm_fb *fb;

uint32_t width, height;
fd_set fds;

int has_init = 0;

/* TODO: Belongs in a header */
#define LDB_EGL_UDATA_NAME "EGLCard"
#define CHECK_EGL(L, I, D) D=(lua_egl_t *)luaL_checkudata(L, I, LDB_EGL_UDATA_NAME); if (D==NULL) { lua_pushnil(L); lua_pushfstring(L, "Argument %d must be a DRM card", I); return 2; }

typedef struct {
	uint32_t width;
	uint32_t height;
	char* egldev;
} lua_egl_t;




static uint32_t find_crtc_for_encoder(const drmModeRes *resources, const drmModeEncoder *encoder) {
	int i;

	for (i = 0; i < resources->count_crtcs; i++) {
		/* possible_crtcs is a bitmask as described here:
		 * https://dvdhrm.wordpress.com/2012/09/13/linux-drm-mode-setting-api
		 */
		const uint32_t crtc_mask = 1 << i;
		const uint32_t crtc_id = resources->crtcs[i];
		if (encoder->possible_crtcs & crtc_mask) {
			return crtc_id;
		}
	}

	/* no match found */
	return -1;
}

static uint32_t find_crtc_for_connector(const drmModeRes *resources, const drmModeConnector *connector) {
	int i;

	for (i = 0; i < connector->count_encoders; i++) {
		const uint32_t encoder_id = connector->encoders[i];
		drmModeEncoder *encoder = drmModeGetEncoder(drm.fd, encoder_id);

		if (encoder) {
			const uint32_t crtc_id = find_crtc_for_encoder(resources, encoder);

			drmModeFreeEncoder(encoder);
			if (crtc_id != 0) {
				return crtc_id;
			}
		}
	}

	/* no match found */
	return -1;
}

static int init_drm(const char* dri_dev) {
	drmModeRes *resources;
	drmModeConnector *connector = NULL;
	drmModeEncoder *encoder = NULL;
	int i, area;


	if (dri_dev==NULL) {
		printf("Using default dri device /dev/dri/card0\n");
		drm.fd = open("/dev/dri/card0", O_RDWR);
	} else {
		printf("Using dri device %s\n", dri_dev);
		drm.fd = open(dri_dev, O_RDWR);
	}

	if (drm.fd < 0) {
		printf("could not open drm device\n");
		return -1;
	}

	resources = drmModeGetResources(drm.fd);
	if (!resources) {
		printf("drmModeGetResources failed: %s\n", strerror(errno));
		return -1;
	}

	/* find a connected connector: */
	for (i = 0; i < resources->count_connectors; i++) {
		connector = drmModeGetConnector(drm.fd, resources->connectors[i]);
		if (connector->connection == DRM_MODE_CONNECTED) {
			/* it's connected, let's use this! */
			break;
		}
		drmModeFreeConnector(connector);
		connector = NULL;
	}

	if (!connector) {
		/* we could be fancy and listen for hotplug events and wait for
		 * a connector..
		 */
		printf("no connected connector!\n");
		return -1;
	}

	/* find prefered mode or the highest resolution mode: */
	for (i = 0, area = 0; i < connector->count_modes; i++) {
		drmModeModeInfo *current_mode = &connector->modes[i];

		if (current_mode->type & DRM_MODE_TYPE_PREFERRED) {
			drm.mode = current_mode;
		}

		int current_area = current_mode->hdisplay * current_mode->vdisplay;
		if (current_area > area) {
			drm.mode = current_mode;
			area = current_area;
		}
	}

	if (!drm.mode) {
		printf("could not find mode!\n");
		return -1;
	}

	/* find encoder: */
	for (i = 0; i < resources->count_encoders; i++) {
		encoder = drmModeGetEncoder(drm.fd, resources->encoders[i]);
		if (encoder->encoder_id == connector->encoder_id)
			break;
		drmModeFreeEncoder(encoder);
		encoder = NULL;
	}

	if (encoder) {
		drm.crtc_id = encoder->crtc_id;
	} else {
		uint32_t crtc_id = find_crtc_for_connector(resources, connector);
		if (crtc_id == 0) {
			printf("no crtc found!\n");
			return -1;
		}

		drm.crtc_id = crtc_id;
	}

	drm.connector_id = connector->connector_id;

	return 0;
}

static int init_gbm(void) {
	gbm.dev = gbm_create_device(drm.fd);

	gbm.surface = gbm_surface_create(gbm.dev,
			drm.mode->hdisplay, drm.mode->vdisplay,
			GBM_FORMAT_XRGB8888,
			GBM_BO_USE_SCANOUT | GBM_BO_USE_RENDERING);
	if (!gbm.surface) {
		printf("failed to create gbm surface\n");
		return -1;
	}

	return 0;
}

static int init_gl(void) {
	EGLint major, minor, n;

	static const EGLint context_attribs[] = {
		EGL_CONTEXT_CLIENT_VERSION, 2,
		EGL_NONE
	};

	static const EGLint config_attribs[] = {
		EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
		EGL_RED_SIZE, 1,
		EGL_GREEN_SIZE, 1,
		EGL_BLUE_SIZE, 1,
		EGL_ALPHA_SIZE, 0,
		EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
		EGL_NONE
	};

	PFNEGLGETPLATFORMDISPLAYEXTPROC get_platform_display = NULL;
	get_platform_display = (void *) eglGetProcAddress("eglGetPlatformDisplayEXT");
	assert(get_platform_display != NULL);

	gl.display = get_platform_display(EGL_PLATFORM_GBM_KHR, gbm.dev, NULL);

	if (!eglInitialize(gl.display, &major, &minor)) {
		printf("failed to initialize\n");
		return -1;
	}

	printf("Using display %p with EGL version %d.%d\n", gl.display, major, minor);
	printf("EGL Version \"%s\"\n", eglQueryString(gl.display, EGL_VERSION));
	printf("EGL Vendor \"%s\"\n", eglQueryString(gl.display, EGL_VENDOR));
	printf("EGL Extensions \"%s\"\n", eglQueryString(gl.display, EGL_EXTENSIONS));

	if (!eglBindAPI(EGL_OPENGL_ES_API)) {
		printf("failed to bind api EGL_OPENGL_ES_API\n");
		return -1;
	}

	if (!eglChooseConfig(gl.display, config_attribs, &gl.config, 1, &n) || n != 1) {
		printf("failed to choose config: %d\n", n);
		return -1;
	}

	gl.context = eglCreateContext(gl.display, gl.config, EGL_NO_CONTEXT, context_attribs);
	if (gl.context == NULL) {
		printf("failed to create context\n");
		return -1;
	}

	gl.surface = eglCreateWindowSurface(gl.display, gl.config, gbm.surface, NULL);
	if (gl.surface == EGL_NO_SURFACE) {
		printf("failed to create egl surface\n");
		return -1;
	}

	/* connect the context to the surface */
	eglMakeCurrent(gl.display, gl.surface, gl.surface, gl.context);

	printf("GL Extensions: \"%s\"\n", glGetString(GL_EXTENSIONS));

	return 0;
}



static void drm_fb_destroy_callback(struct gbm_bo *bo, void *data) {
	struct drm_fb *fb = data;
	struct gbm_device *gbm = gbm_bo_get_device(bo);

	if (fb->fb_id) {
		drmModeRmFB(drm.fd, fb->fb_id);
	}

	free(fb);
}

static struct drm_fb * drm_fb_get_from_bo(struct gbm_bo *bo) {
	struct drm_fb *fb = gbm_bo_get_user_data(bo);
	uint32_t width, height, stride, handle;
	int ret;

	if (fb)
		return fb;

	fb = calloc(1, sizeof *fb);
	fb->bo = bo;

	width = gbm_bo_get_width(bo);
	height = gbm_bo_get_height(bo);
	stride = gbm_bo_get_stride(bo);
	handle = gbm_bo_get_handle(bo).u32;

	ret = drmModeAddFB(drm.fd, width, height, 24, 32, stride, handle, &fb->fb_id);
	if (ret) {
		printf("failed to create fb: %s\n", strerror(errno));
		free(fb);
		return NULL;
	}

	gbm_bo_set_user_data(bo, fb, drm_fb_destroy_callback);

	return fb;
}

static void page_flip_handler(int fd, unsigned int frame, unsigned int sec, unsigned int usec, void *data) {
	int *waiting_for_flip = data;
	*waiting_for_flip = 0;
}




static int lua_egl_card_update(lua_State *L) {
	lua_egl_t *egl;
	CHECK_EGL(L, 1, egl)

	/* Draw code here */
	// on top of stack must be a function
	if (lua_isfunction(L, 2)) {
		// run lua function
		if (lua_pcall(L, 0, 0, 0) != 0) {
			const char* err_str = lua_tostring(L, -1);
			lua_pushnil(L);
			if (err_str) {
				luaL_traceback(L, L, err_str, 0);
			} else {
				lua_pushstring(L, "Lua error in draw function");
			}
			return 2;
		}
	}

	struct gbm_bo *next_bo;
	int waiting_for_flip = 1;

	drmEventContext evctx = {
		.version = DRM_EVENT_CONTEXT_VERSION,
		.page_flip_handler = page_flip_handler,
	};

	eglSwapBuffers(gl.display, gl.surface);
	next_bo = gbm_surface_lock_front_buffer(gbm.surface);
	fb = drm_fb_get_from_bo(next_bo);

	/*
	 * Here you could also update drm plane layers if you want
	 * hw composition
	 */

	if (drmModePageFlip(drm.fd, drm.crtc_id, fb->fb_id, DRM_MODE_PAGE_FLIP_EVENT, &waiting_for_flip)) {
		lua_pushnil(L);
		lua_pushfstring(L, "failed to queue page flip: %s", strerror(errno));
		return 2;
	}

	while (waiting_for_flip) {
		int ret = select(drm.fd + 1, &fds, NULL, NULL, NULL);
		if (ret < 0) {
			lua_pushnil(L);
			lua_pushfstring(L, "select err: %s", strerror(errno));
			return 2;
		} else if (ret == 0) {
			lua_pushnil(L);
			lua_pushstring(L, "select timeout!");
			return 2;
		} else if (FD_ISSET(0, &fds)) {
			lua_pushnil(L);
			lua_pushstring(L, "user interrupted!");
			return 2;
		}
		drmHandleEvent(drm.fd, &evctx);
	}

	/* release last buffer to render on again: */
	gbm_surface_release_buffer(gbm.surface, bo);
	bo = next_bo;

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_egl_card_create_vao(lua_State *L) {
	lua_egl_t *egl;
	CHECK_EGL(L, 1, egl)

	if (!lua_istable(L, 2) || !lua_istable(L, 3)) {
		lua_pushnil(L);
		lua_pushstring(L, "Second argument needs to be a table");
		return 2;
	}

	// Convert Lua vertice table to vertice array
	size_t vertices_len = lua_objlen(L, 2);
	float* vertices = calloc(vertices_len, sizeof(float));
	if (!vertices) {
		lua_pushnil(L);
		lua_pushstring(L, "Can't allocate vertice memory.");
		return 2;
	}
	if (vertices_len<=0) {
		lua_pushnil(L);
		lua_pushstring(L, "Must provide >0 vertice data");
		return 2;
	}
	for (int i=0; i<vertices_len; i++) {
		lua_rawgeti(L, 2, i+1);
		float val = lua_tonumber(L, -1);
		lua_pop(L, 1);

		printf("#######    test---: %f\n", val);
		vertices[i] = val;
	}

	// Convert Lua indice table to vertice array
	size_t indices_len = lua_objlen(L, 3);
	unsigned int* indices = calloc(indices_len, sizeof(unsigned int));
	if (!indices) {
		lua_pushnil(L);
		lua_pushstring(L, "Can't allocate indice memory.");
		return 2;
	}
	if (indices_len<=0) {
		lua_pushnil(L);
		lua_pushstring(L, "Must provide >0 indice data");
		return 2;
	}
	for (int i=0; i<indices_len; i++) {
		lua_rawgeti(L, 3, i+1);
		unsigned int val = lua_tointeger(L, -1);
		lua_pop(L, 1);

		printf("#######    test2---: %d\n", val);
		indices[i] = val;
	}



    unsigned int VBO, VAO, EBO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
	glGenBuffers(1, &EBO);
    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, vertices_len*sizeof(float), vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices_len*sizeof(unsigned int), indices, GL_STATIC_DRAW);


	// TODO: Find a better way than hardcoding this
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    // color attribute
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);
    // texture coord attribute
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
    glEnableVertexAttribArray(2);

    // note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
    glBindBuffer(GL_ARRAY_BUFFER, 0);

	GLenum err = glGetError();
	if (err != GL_NO_ERROR) {
		return 0;
	}

	// return the created object ids
	lua_pushinteger(L, VBO);
	lua_pushinteger(L, VAO);
	lua_pushinteger(L, EBO);
	return 3;
}

static int lua_egl_card_create_program(lua_State *L) {
	lua_egl_t *egl;
	CHECK_EGL(L, 1, egl)

	if ((lua_isstring(L, 2) == 0) || (lua_isstring(L, 3) == 0)) {
		lua_pushnil(L);
		lua_pushstring(L, "3 arguments required: EGLCard, vshader, fshader");
		return 2;
	}
	const char* vertexShaderSource = lua_tostring(L, 2);
	const char* fragmentShaderSource = lua_tostring(L, 3);

	unsigned int vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);

    // check for shader compile errors
    int success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
		lua_pushnil(L);
		lua_pushstring(L, "vshader error");
		lua_pushlstring(L, infoLog, 512);
		// TODO: Cleanup?
		return 3;
    }
    // fragment shader
    unsigned int fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);
    // check for shader compile errors
    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
    if (!success) {
		glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
		lua_pushnil(L);
		lua_pushstring(L, "fshader error");
		lua_pushlstring(L, infoLog, 512);
		// TODO: Cleanup?
		return 3;
    }
    // link shaders
    unsigned int shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    // check for linking errors
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if (!success) {
        //glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
		lua_pushnil(L);
		//lua_pushlstring(L, infoLog, 512);
		lua_pushstring(L, "Shader linking failed.");
		// TODO: Cleanup?
		return 2;
    }

	// cleanup
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

	// return complete program id
	lua_pushinteger(L, shaderProgram);
	return 1;
}

static int lua_egl_card_create_texture2d_from_db(lua_State *L) {
	lua_egl_t *egl;
	CHECK_EGL(L, 1, egl)

	drawbuffer_t *db;
	LUA_LDB_CHECK_DB(L, 2, db)

	int w = db->w;
	int h = db->h;

	// TODO: Support more pixel formats
	if (db->pxfmt != LDB_PXFMT_24BPP_RGB) {
		lua_pushnil(L);
		lua_pushstring(L, "Bad pixel format!");
		return 2;
	}

	unsigned int texture;
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, w, h, 0, GL_RGB, GL_UNSIGNED_BYTE, db->data);
	glGenerateMipmap(GL_TEXTURE_2D);

	GLenum err = glGetError();
	if (err != GL_NO_ERROR) {
		return 0;
	}

	lua_pushinteger(L, texture);
	return 1;
}

static int lua_egl_card_get_info(lua_State *L) {
	lua_egl_t *egl;
	CHECK_EGL(L, 1, egl)

	lua_pop(L, 1);
	lua_pushinteger(L, gbm_bo_get_width(bo));
	lua_pushinteger(L, gbm_bo_get_height(bo));
	return 2;
}

static int lua_egl_card_tostring(lua_State *L) {
	lua_egl_t *egl = (lua_egl_t *)luaL_checkudata(L, 1, LDB_EGL_UDATA_NAME);

	if (!egl) {
		lua_pushnil(L);
		lua_pushstring(L, "Argument 1 must be a EGL device");
		return 2;
	}

	lua_pushfstring(L, "EGLcard: %s(%dx%d)", egl->egldev, gbm_bo_get_width(bo), gbm_bo_get_height(bo));
    return 1;
}

static int lua_egl_card_close(lua_State *L) {
	lua_egl_t *egl = (lua_egl_t *)luaL_checkudata(L, 1, LDB_EGL_UDATA_NAME);
	if (!egl) {
		lua_pushnil(L);
		lua_pushstring(L, "Argument 1 must be a EGL device");
		return 2;
	}

	return 0;
}

static int lua_egl_card_clear(lua_State *L) {
	lua_egl_t *egl;
	CHECK_EGL(L, 1, egl)

	float r = lua_tonumber(L, 2);
	float g = lua_tonumber(L, 3);
	float b = lua_tonumber(L, 4);
	float a = lua_tonumber(L, 5);

	glClearColor(r,g,b,a);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	return 0;
}

static int lua_egl_card_use_program(lua_State *L) {
	lua_egl_t *egl;
	CHECK_EGL(L, 1, egl)

	if (!lua_isnumber(L, 2)) {
		return 0;
	}
	unsigned int program_id = lua_tointeger(L, 2);

	glUseProgram(program_id);

	GLenum err = glGetError();
	if (err != GL_NO_ERROR) {
		lua_pushnil(L);
		lua_pushinteger(L, err);
		return 2;
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_egl_card_bind_texture2d(lua_State *L) {
	lua_egl_t *egl;
	CHECK_EGL(L, 1, egl)

	if (!lua_isnumber(L, 2)) {
		return 0;
	}
	unsigned int tex_id = lua_tointeger(L, 2);

	glBindTexture(GL_TEXTURE_2D, tex_id);

	GLenum err = glGetError();
	if (err != GL_NO_ERROR) {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}


static int lua_egl_card_bind_VAO(lua_State *L) {
	lua_egl_t *egl;
	CHECK_EGL(L, 1, egl)

	if (!lua_isnumber(L, 2)) {
		return 0;
	}
	unsigned int vao_id = lua_tointeger(L, 2);

	glBindVertexArray(vao_id);

	GLenum err = glGetError();
	if (err != GL_NO_ERROR) {
		return 0;
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int lua_egl_card_draw_triangles(lua_State *L) {
	lua_egl_t *egl;
	CHECK_EGL(L, 1, egl)

	if (!lua_isnumber(L, 2)) {
		return 0;
	}
	unsigned int vertice_count = lua_tointeger(L, 2);

	glDrawElements(GL_TRIANGLES, vertice_count, GL_UNSIGNED_INT, 0);

	lua_pushboolean(L, 1);
	return 1;
}



static int lua_egl_new_card(lua_State *L) {
	// TODO: Currently only allows calling this function once
	if (has_init) {
		lua_pushnil(L);
		lua_pushstring(L, "Can't create two card simultaneously.");
		return 2;
	}
	has_init = 1;

	// get single argument
	size_t egldev_len;
	const char* egldev = lua_tolstring(L, 1, &egldev_len);
	if ((!egldev) || (egldev_len<1)) {
		lua_pushnil(L);
		lua_pushstring(L, "First argument must be a device");
		return 2;
	}

	// put new userdata on stack
	lua_egl_t* card = (lua_egl_t*)lua_newuserdata(L, sizeof(lua_egl_t));
	card->egldev = strndup(egldev, egldev_len);


	int ret;

	ret = init_drm(egldev);
	if (ret) {
		lua_pushnil(L);
		lua_pushfstring(L, "failed to initialize DRM device %q(%d)", egldev, ret);
		return 2;
	}

	FD_ZERO(&fds);
	FD_SET(0, &fds);
	FD_SET(drm.fd, &fds);

	ret = init_gbm();
	if (ret) {
		lua_pushnil(L);
		lua_pushfstring(L, "failed to initialize GBM: %d", ret);
		return 2;
	}

	ret = init_gl();
	if (ret) {
		lua_pushnil(L);
		lua_pushfstring(L, "failed to initialize EGL: %d", ret);
		return 2;
	}

	/* clear the color buffer */
	glClearColor(0.0, 0.0, 0.0, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);

	eglSwapBuffers(gl.display, gl.surface);
	bo = gbm_surface_lock_front_buffer(gbm.surface);
	fb = drm_fb_get_from_bo(bo);
	width = gbm_bo_get_width(bo);
	height = gbm_bo_get_height(bo);

	/* set mode: */
	ret = drmModeSetCrtc(drm.fd, drm.crtc_id, fb->fb_id, 0, 0, &drm.connector_id, 1, drm.mode);
	if (ret) {
		lua_pushnil(L);
		lua_pushfstring(L, "failed to set mode(%d): %s", ret, strerror(errno));
		return 2;
	}

	// push/create metatable for drm userdata. The same metatable is used for every drm instance.
    if (luaL_newmetatable(L, LDB_EGL_UDATA_NAME)) {
		lua_pushstring(L, "__index");
		lua_newtable(L);
		LUA_T_PUSH_S_CF("get_info", lua_egl_card_get_info)
		LUA_T_PUSH_S_CF("update", lua_egl_card_update)
		LUA_T_PUSH_S_CF("create_program", lua_egl_card_create_program)
		LUA_T_PUSH_S_CF("create_texture2d_from_db", lua_egl_card_create_texture2d_from_db)
		LUA_T_PUSH_S_CF("create_vao", lua_egl_card_create_vao)
		LUA_T_PUSH_S_CF("tostring", lua_egl_card_tostring)
		LUA_T_PUSH_S_CF("clear", lua_egl_card_clear)
		LUA_T_PUSH_S_CF("use_program", lua_egl_card_use_program)
		LUA_T_PUSH_S_CF("bind_VAO", lua_egl_card_bind_VAO)
		LUA_T_PUSH_S_CF("bind_texture2d", lua_egl_card_bind_texture2d)
		LUA_T_PUSH_S_CF("draw_triangles", lua_egl_card_draw_triangles)
		lua_settable(L, -3);

		LUA_T_PUSH_S_CF("__gc", lua_egl_card_close)
		LUA_T_PUSH_S_CF("__tostring", lua_egl_card_tostring)
	}

	// apply metatable to userdata
    lua_setmetatable(L, -2);

	// return userdata
    return 1;
}



LUALIB_API int luaopen_ldb_egl(lua_State *L) {
    lua_newtable(L);

    LUA_T_PUSH_S_S("version", LDB_VERSION)
    LUA_T_PUSH_S_CF("new_card", lua_egl_new_card)

    return 1;
}
