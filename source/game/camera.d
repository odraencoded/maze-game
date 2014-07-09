module camera;

import dsfml.system.vector2;

/**
 * A focus-seeking camera.
 *
 * Use by setting a focus point and a speed.
 * The camera will move its center toward the focus through the update method.
 */
class Camera {
	Vector2f center = Vector2f(0, 0);
	Vector2f focus = Vector2f(0, 0);
	float speed = 1;
	
	/**
	 * Convenience method that sets both center and focus to a value.
	 */
	void reset(const Vector2f newFocus = Vector2f(0, 0)) pure nothrow @safe {
		center = focus = newFocus;
	}
	
	/**
	 * Moves center by
	 * the distance from center to focus
	 * times the camera speed
	 * times delta
	 */
	void update(const float delta) pure nothrow @safe {
		assert(speed >= 0);
		
		auto offset = center - focus;
		auto vel = offset * speed * delta * -1;
		center += vel;
	}
}