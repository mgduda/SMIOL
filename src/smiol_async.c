#include <stdio.h>
#include <stdlib.h>
#include "smiol_async.h"


/********************************************************************************
 *
 * SMIOL_async_init
 *
 * Short, one-line description.
 *
 * Detailed description.
 *
 ********************************************************************************/
int SMIOL_async_init(struct SMIOL_context *context)
{
	int ierr;
	pthread_mutexattr_t mutexattr;
	pthread_condattr_t condattr;


	/*
	 * Mutex setup
	 */
	context->mutex = malloc(sizeof(pthread_mutex_t));

	ierr = pthread_mutexattr_init(&mutexattr);
	if (ierr) {
		fprintf(stderr, "Error: pthread_mutexattr_init: %i\n", ierr);
		return 1;
	}

	ierr = pthread_mutex_init(context->mutex, (const pthread_mutexattr_t *)&mutexattr);
	if (ierr) {
		fprintf(stderr, "Error: pthread_mutex_init: %i\n", ierr);
		return 1;
	}

	ierr = pthread_mutexattr_destroy(&mutexattr);
	if (ierr) {
		fprintf(stderr, "Error: pthread_mutexattr_destroy: %i\n", ierr);
		return 1;
	}


	/*
	 * Condition variable setup
	 */
	context->cond = malloc(sizeof(pthread_cond_t));

	ierr = pthread_condattr_init(&condattr);
	if (ierr) {
		fprintf(stderr, "Error: pthread_condattr_init: %i\n", ierr);
		return 1;
	}

	ierr = pthread_cond_init(context->cond, (const pthread_condattr_t *)&condattr);
	if (ierr) {
		fprintf(stderr, "Error: pthread_cond_init: %i\n", ierr);
		return 1;
	}

	ierr = pthread_condattr_destroy(&condattr);
	if (ierr) {
		fprintf(stderr, "Error: pthread_condattr_destroy: %i\n", ierr);
		return 1;
	}

	return 0;
}


/********************************************************************************
 *
 * SMIOL_async_finalize
 *
 * Short, one-line description.
 *
 * Detailed description.
 *
 ********************************************************************************/
int SMIOL_async_finalize(struct SMIOL_context *context)
{
	int ierr;

	ierr = pthread_mutex_destroy(context->mutex);
	if (ierr) {
		fprintf(stderr, "Error: pthread_mutex_destroy: %i\n", ierr);
		return 1;
	}

	free(context->mutex);
	context->mutex = NULL;

	ierr = pthread_cond_destroy(context->cond);
	if (ierr) {
		fprintf(stderr, "Error: pthread_cond_destroy: %i\n", ierr);
		return 1;
	}

	free(context->cond);
	context->cond = NULL;

	return 0;
}


/********************************************************************************
 *
 * SMIOL_async_queue_add
 *
 * Short, one-line description.
 *
 * Detailed description.
 *
 ********************************************************************************/
void SMIOL_async_queue_add(struct SMIOL_file *file, struct SMIOL_async_buffer *b)
{
	if (!file->head && !file->tail) {
		file->head = b;
		file->tail = b;
	} else if (file->head && file->tail) {
		file->head->next = b;
		file->head = b;
	} else {
		fprintf(stderr, "List error: only one of head or tail was associated!\n");
	}
}


/********************************************************************************
 *
 * SMIOL_async_queue_remove
 *
 * Short, one-line description.
 *
 * Detailed description.
 *
 ********************************************************************************/
struct SMIOL_async_buffer *SMIOL_async_queue_remove(struct SMIOL_file *file)
{
	struct SMIOL_async_buffer *b;

	if (!file->tail) {
		b = NULL;
	} else {
		b = file->tail;
		file->tail = file->tail->next;
		if (!file->tail) {
			file->head = NULL;
		}
	}

	return b;
}


/********************************************************************************
 *
 * SMIOL_async_launch_thread
 *
 * Short, one-line description.
 *
 * Detailed description.
 *
 ********************************************************************************/
void SMIOL_async_launch_thread(pthread_t **thread, void *(*func)(void *), void *arg)
{
	int ierr;
	pthread_attr_t attr;

	*thread = malloc(sizeof(pthread_t));

	ierr = pthread_attr_init(&attr);
	if (ierr) {
		fprintf(stderr, "Error: pthread_attr_init: %i\n", ierr);
	}

	ierr = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
	if (ierr) {
		fprintf(stderr, "Error: pthread_attr_setdetachedstate: %i\n", ierr);
	}

	ierr = pthread_create(*thread, (const pthread_attr_t *)&attr, func, arg);
	if (ierr) {
		fprintf(stderr, "Error: pthread_create: %i\n", ierr);
	}

	ierr = pthread_attr_destroy(&attr);
	if (ierr) {
		fprintf(stderr, "Error: pthread_attr_destroy: %i\n", ierr);
	}
}


/********************************************************************************
 *
 * SMIOL_async_join_thread
 *
 * Short, one-line description.
 *
 * Detailed description.
 *
 ********************************************************************************/
void SMIOL_async_join_thread(pthread_t **thread)
{
	int ierr;

	if (*thread != NULL) {
		ierr = pthread_join(**thread, NULL);
		if (ierr) {
			fprintf(stderr, "Error: pthread_create: %i\n", ierr);
		}

		free(*thread);
		*thread = NULL;
	}
}


#if 0
int main(void)
{
	size_t bytes;
	int id;

	smiol_async_init();

	smiol_async_launch_thread();

	id = 1;
	fscanf(stdin, "%lu", &bytes);
	while (bytes != 0) {
		fprintf(stderr, "Queueing up %lu bytes\n", bytes);

		pthread_mutex_lock(&mutex);
		smiol_queue_add(id++, bytes);
		if (!active) {
			smiol_async_join_thread();
			active = 1;
			smiol_async_launch_thread();
		}
		pthread_mutex_unlock(&mutex);

		fscanf(stdin, "%lu", &bytes);
	}

	smiol_async_join_thread();

	smiol_async_finalize();

	fprintf(stderr, "All done!\n");

	return 0;
}
#endif
